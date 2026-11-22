# frozen_string_literal: true

module ReservationService
  # Books a seat. When the bus company's city has payments on, the seat is held as pending_payment
  # with a fare snapshot and a gateway payment is started; otherwise the booking is confirmed at once.
  class Create < Base
    attr_reader :params, :current_user, :reservation, :schedule

    SUCCESS_KEY = 'reservation.create.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      return set_response unless authorize_booking && find_schedule

      schedule.city&.payments_enabled ? create_paid : create_free
    end

    private

    def create_free
      result = ActiveRecord::Base.transaction do
        lock_schedule && check_availability && create_reservation && decrement_seats && set_data && set_response
      end
      schedule_confirmation_email if reservation&.persisted?
      result || set_response
    end

    # The gateway call runs after the hold is committed, so a slow network never holds the
    # schedule row lock.
    def create_paid
      return set_response unless quote_fare

      held = ActiveRecord::Base.transaction do
        (lock_schedule && check_availability && create_reservation(paid_attributes) && decrement_seats) ||
          raise(ActiveRecord::Rollback)
      end
      return set_response unless held

      schedule_hold_expiry
      start_payment
      set_response
    end

    def authorize_booking
      return true unless current_user[:guest]

      add_error('reservation.guest_forbidden')
      false
    end

    def find_schedule
      @schedule = Schedule.find_by(id: params[:schedule_id])
      return true if schedule

      add_error('schedule.not_found')
      false
    end

    def lock_schedule
      schedule.lock!
      true
    end

    def quote_fare
      service = Fares::QuoteForSchedule.new(schedule)
      @quote = service.call
      return true if @quote

      add_error('reservation.not_priced', reason: translate("reservation.not_priced.reasons.#{service.reason}"))
    end

    def check_availability
      return true if schedule.available_seats&.positive?

      add_error('reservation.no_seats')
      false
    end

    def create_reservation(extra_attributes = {})
      @reservation = Reservation.new(
        user_id: booking_user_id,
        schedule_id: schedule.id,
        **extra_attributes
      )
      return true if reservation.save

      add_error('reservation.create.failure', message: reservation.errors.full_messages.join(', '))
      false
    end

    def paid_attributes
      {
        status: :pending_payment,
        fare_amount_minor: @quote.amount_minor,
        currency: @quote.currency,
        fare_breakdown: @quote.to_h,
        fare_table_id: @quote.fare_table_id,
        hold_expires_at: Time.current + Reservation::HOLD_DURATION
      }
    end

    def booking_user_id
      current_user[:admin] ? params[:user_id] || current_user[:user_id] : current_user[:user_id]
    end

    def decrement_seats
      return true if schedule.decrement_available_seat!

      add_error('reservation.no_seats')
      false
    end

    def schedule_confirmation_email
      ReservationConfirmationJob.perform_later(reservation.id)
    end

    def schedule_hold_expiry
      ReservationHoldExpiryJob.set(wait_until: reservation.hold_expires_at).perform_later(reservation.id)
    end

    # On failure the hold ends at once and the seat goes back. The gateway's own error text is
    # logged, never shown to the rider.
    def start_payment
      result = Payments::Start.new(reservation).call
      return set_paid_data(result) if result.success?

      Rails.logger.warn "[ReservationService::Create] payment start failed for #{reservation.uid}: #{result.error}"
      Reservations::Transition.call(reservation, to: :expired, reason: 'payment_start_failed')
      add_error('reservation.payment_start_failed')
    end

    def set_paid_data(result)
      set_data
      @data[:payment] = {
        client_secret: result.data[:client_secret],
        publishable_key: ENV['HYPERSWITCH_PUBLISHABLE_KEY']
      }
    end

    def set_data
      @data = V1::ReservationSerializer.new(reservation).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end

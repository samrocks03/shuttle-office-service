# frozen_string_literal: true

module ReservationService
  class Create < Base
    attr_reader :params, :current_user, :reservation, :schedule

    SUCCESS_KEY = 'reservation.create.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      result = ActiveRecord::Base.transaction do
        authorize_booking && find_and_lock_schedule && check_availability && create_reservation &&
          decrement_seats && set_data && set_response
      end
      schedule_confirmation_email if reservation&.persisted?
      result || set_response
    end

    private

    def authorize_booking
      return true unless current_user[:guest]

      add_error('reservation.guest_forbidden')
      false
    end

    def find_and_lock_schedule
      @schedule = Schedule.lock.find_by(id: params[:schedule_id])
      return true if schedule

      add_error('schedule.not_found')
      false
    end

    def check_availability
      return true if schedule.available_seats&.positive?

      add_error('reservation.no_seats')
      false
    end

    def create_reservation
      @reservation = Reservation.new(
        user_id: booking_user_id,
        schedule_id: schedule.id
      )
      return true if reservation.save

      add_error('reservation.create.failure', message: reservation.errors.full_messages.join(', '))
      false
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

    def set_data
      @data = V1::ReservationSerializer.new(reservation).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end

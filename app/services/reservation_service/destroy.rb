# frozen_string_literal: true

module ReservationService
  # Cancels a booking. A free reservation is deleted as before. A paid one is never deleted (its
  # payment record must stay): it moves to cancelled, open payments are cancelled and a confirmed
  # one is refunded in full. Gateway calls run outside any DB transaction.
  class Destroy < Base
    attr_reader :params, :current_user, :reservation
    SUCCESS_KEY = 'reservation.destroy.success.message'
    CANCEL_SUCCESS_KEY = 'reservation.cancel.success.message'
    CANCEL_REASON = 'reservation_cancelled'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      return set_response unless find_reservation
      return cancel_paid if reservation.paid?

      result = ActiveRecord::Base.transaction do
        lock_schedule && destroy_reservation && increment_seats && set_success
      end
      result || set_response
    end

    private

    def find_reservation
      @reservation = ReservationRepository.scope_for(current_user).find_by(uid: params[:id])
      return true if reservation

      add_error('reservation.not_found')
      false
    end

    def lock_schedule
      @schedule = Schedule.lock.find_by(id: reservation.schedule_id)
      return true if @schedule

      add_error('schedule.not_found')
      false
    end

    def destroy_reservation
      return true if reservation.destroy

      add_error('reservation.destroy.failure')
      false
    end

    def increment_seats
      @schedule.increment_available_seat!
      true
    end

    def set_success
      @message = translate(SUCCESS_KEY)
      set_response
    end

    def cancel_paid
      cancelled =
        if reservation.pending_payment?
          cancel_pending
        elsif reservation.confirmed?
          cancel_confirmed
        else
          add_error('reservation.not_cancellable')
        end
      return set_response unless cancelled

      @data = V1::ReservationSerializer.new(reservation.reload).serializable_hash
      @message = translate(CANCEL_SUCCESS_KEY)
      set_response
    end

    # The reservation is cancelled first, so a payment that succeeds while we talk to the gateway
    # meets a cancelled reservation and is refunded (the late-payment rule).
    def cancel_pending
      return false unless transition_to_cancelled

      reservation.open_payments.each { |payment| cancel_payment(payment) }
      true
    end

    def cancel_confirmed
      return add_error('reservation.cancel_too_late') if reservation.schedule.departs_at <= Time.current
      return false unless transition_to_cancelled

      payment = reservation.succeeded_payment
      refund(payment) if payment
      true
    end

    def transition_to_cancelled
      return true if Reservations::Transition.call(reservation, to: :cancelled, reason: 'cancelled_by_rider')

      add_error('reservation.not_cancellable')
    end

    # A refused cancel does not stop the cancellation; the error is kept on the payment.
    def cancel_payment(payment)
      result = gateway_call { |gateway| gateway.cancel_payment(payment.gateway_payment_id) }
      if result.success?
        payment.update!(status: result.data[:status].presence || 'cancelled', last_error: nil)
      else
        payment.update!(last_error: result.error)
      end
    end

    # A refused refund keeps the reservation cancelled and is stored as failed for an admin retry.
    def refund(payment)
      result = gateway_call do |gateway|
        gateway.create_refund(payment_id: payment.gateway_payment_id, amount_minor: payment.amount_minor,
                              reason: CANCEL_REASON)
      end
      attributes = { amount_minor: payment.amount_minor, reason: CANCEL_REASON }
      if result.success?
        payment.refunds.create!(attributes.merge(gateway_refund_id: result.data[:id],
                                                 status: result.data[:status].presence || 'pending'))
      else
        payment.refunds.create!(attributes.merge(status: 'failed', last_error: result.error))
      end
    end

    def gateway_call
      yield Payments::Gateway.current
    rescue Payments::NotConfigured => e
      Payments::Result.new(success: false, error: e.message)
    end
  end
end

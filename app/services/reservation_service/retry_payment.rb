# frozen_string_literal: true

module ReservationService
  # Starts a new gateway payment for a held seat whose latest payment failed or was cancelled.
  # The hold time is not extended: once hold_expires_at passes, the expiry job releases the seat.
  #
  # The eligibility check and Payments::Start run under the reservation row lock, so two concurrent
  # retries cannot both see a failed payment and create two payments: the second waits, then sees the
  # new open payment and is refused. The gateway call therefore holds the reservation lock (never the
  # schedule lock) for one network round trip.
  class RetryPayment < Base
    attr_reader :params, :current_user, :reservation
    SUCCESS_KEY = 'reservation.retry_payment.success.message'
    RETRYABLE = %w[failed cancelled].freeze

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      return set_response unless find_reservation

      response = reservation.with_lock { start_payment if retry_allowed? }
      response || set_response
    end

    private

    def find_reservation
      @reservation = ReservationRepository.scope_for(current_user).find_by(uid: params[:id])
      return true if reservation

      add_error('reservation.not_found')
      false
    end

    # with_lock has reloaded the reservation, so this sees the committed state.
    def retry_allowed?
      allowed = reservation.pending_payment? && Time.current < reservation.hold_expires_at &&
                RETRYABLE.include?(reservation.payments.order(created_at: :desc, id: :desc).first&.status)
      add_error('reservation.retry_not_allowed') unless allowed
      allowed
    end

    # The gateway's own error text is logged, never shown to the rider.
    def start_payment
      result = Payments::Start.new(reservation).call
      unless result.success?
        Rails.logger.warn "[ReservationService::RetryPayment] payment start failed for #{reservation.uid}: " \
                          "#{result.error}"
        return add_error('reservation.payment_start_failed')
      end

      success_response({ client_secret: result.data[:client_secret],
                         publishable_key: ENV['HYPERSWITCH_PUBLISHABLE_KEY'] }, translate(SUCCESS_KEY))
    end
  end
end

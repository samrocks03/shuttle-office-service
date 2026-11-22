# frozen_string_literal: true

module ReservationService
  # Reports where a reservation's payment stands. While the reservation is pending_payment the
  # latest payment is first synced with the gateway and applied through Payments::ApplyStatus (the
  # only way a payment becomes succeeded), so the rider sees the outcome even if the webhook is late.
  # A gateway that fails or is not configured never fails the read: the stored state is returned.
  class PaymentStatus < Base
    attr_reader :params, :current_user, :reservation
    SUCCESS_KEY = 'reservation.payment_status.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      return set_response unless find_reservation

      sync_latest_payment if reservation.pending_payment?
      success_response(payment_data, translate(SUCCESS_KEY))
    end

    private

    def find_reservation
      @reservation = ReservationRepository.scope_for(current_user).find_by(uid: params[:id])
      return true if reservation

      add_error('reservation.not_found')
      false
    end

    def latest_payment
      reservation.payments.order(created_at: :desc, id: :desc).first
    end

    def sync_latest_payment
      payment = latest_payment
      return unless payment

      result = Payments::Gateway.current.fetch_payment(payment.gateway_payment_id, sync: true)
      if result.success?
        Payments::ApplyStatus.new(payment, result.data).call
      else
        Rails.logger.warn "[ReservationService::PaymentStatus] sync failed for #{reservation.uid}: #{result.error}"
      end
    rescue Payments::NotConfigured => e
      Rails.logger.warn "[ReservationService::PaymentStatus] sync skipped for #{reservation.uid}: #{e.message}"
    end

    def payment_data
      reservation.reload
      payment = latest_payment
      {
        status: reservation.status,
        payment_status: payment&.status,
        connector: payment&.connector,
        hold_expires_at: reservation.hold_expires_at
      }
    end
  end
end

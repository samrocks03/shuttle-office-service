# frozen_string_literal: true

# Ends a payment hold at hold_expires_at. Queued before the payment starts, so it may find the
# reservation already confirmed, cancelled or expired; then it does nothing.
#
# It first asks the gateway for the latest status of every open payment and applies it, so a
# payment that succeeded confirms the booking instead of losing the seat. While a payment is still
# in flight (or its status cannot be read), it checks again every RETRY_WAIT, at most MAX_RETRIES
# times. Then it cancels the open payments and expires the reservation; a payment that succeeds
# after that is refunded by Payments::ApplyStatus.
class ReservationHoldExpiryJob < ApplicationJob
  queue_as :default

  MAX_RETRIES = 5
  RETRY_WAIT = 2.minutes
  IN_FLIGHT = %w[processing requires_customer_action].freeze
  REASON = 'hold_expired'

  def perform(reservation_id, attempt = 0)
    reservation = Reservation.find_by(id: reservation_id)
    return unless reservation&.pending_payment?

    gateway = configured_gateway(reservation, attempt)
    unsettled = gateway.nil? || reservation.open_payments.map { |payment| in_flight?(gateway, payment) }.any?
    return unless reservation.reload.pending_payment?

    if unsettled && attempt < MAX_RETRIES
      self.class.set(wait: RETRY_WAIT).perform_later(reservation.id, attempt + 1)
      log(reservation, attempt, 'payment not settled, checking again')
      return
    end

    reservation.open_payments.each { |payment| cancel(gateway, payment) } if gateway
    expired = Reservations::Transition.call(reservation, to: :expired, from: :pending_payment, reason: REASON)
    log(reservation, attempt, 'hold expired') if expired
  end

  private

  def configured_gateway(reservation, attempt)
    Payments::Gateway.current
  rescue Payments::NotConfigured
    log(reservation, attempt, 'payment gateway not configured')
    nil
  end

  # Fetches the gateway's view of the payment and applies it. True when the payment may still
  # succeed: the gateway reports it in flight, or its status could not be read.
  def in_flight?(gateway, payment)
    result = gateway.fetch_payment(payment.gateway_payment_id, sync: true)
    unless result.success?
      Rails.logger.warn "[ReservationHoldExpiryJob] could not fetch payment #{payment.gateway_payment_id}"
      return true
    end

    Payments::ApplyStatus.new(payment, result.data).call
    IN_FLIGHT.include?(result.data[:status])
  end

  # Statuses change only through ApplyStatus; a refused cancel is recorded on the payment.
  def cancel(gateway, payment)
    result = gateway.cancel_payment(payment.gateway_payment_id)
    if result.success?
      Payments::ApplyStatus.new(payment, result.data).call if result.data[:status].present?
    else
      payment.update!(last_error: result.error)
      Rails.logger.warn "[ReservationHoldExpiryJob] could not cancel payment #{payment.gateway_payment_id}"
    end
  end

  def log(reservation, attempt, message)
    Rails.logger.info "[ReservationHoldExpiryJob] #{reservation.uid} attempt #{attempt}: #{message}"
  end
end

# frozen_string_literal: true

# Backstop for missed webhooks (a local Hyperswitch cannot always be reached by the processor).
# Each run:
# 1. polls the gateway for refunds still pending and applies the reported status;
# 2. sweeps payments still open on a reservation that is already cancelled or expired (changed in
#    the last OPEN_PAYMENT_WINDOW): it syncs each with the gateway, so a late success is recorded
#    and refunded once by Payments::ApplyStatus instead of leaving the rider charged with no seat.
# Every status goes through Payments::ApplyStatus, which moves it forward only. One record that
# fails (gateway error or exception) is logged by id and skipped; the rest still run.
#
# Self-rescheduling: every run queues the next one INTERVAL later, also when the run fails, and a
# failed run is discarded rather than retried so a retry cannot start a second chain. Start the
# chain once with `bin/rails payments:start_refund_sync`. Runs are idempotent, so an accidental
# second chain only adds gateway calls; it cannot change a refund twice.
class RefundSyncJob < ApplicationJob
  queue_as :default

  INTERVAL = 10.minutes
  MIN_AGE = 1.minute
  OPEN_PAYMENT_WINDOW = 48.hours
  BATCH_SIZE = 100
  FINISHED_RESERVATION_STATUSES = %w[cancelled expired].freeze

  discard_on StandardError

  def perform
    gateway = Payments::Gateway.current
    Refund.includes(:payment).where(status: 'pending').where.not(gateway_refund_id: nil)
          .where(created_at: ..MIN_AGE.ago).find_each { |refund| sync_refund(gateway, refund) }
    open_payments_on_finished_reservations.each { |payment| sync_payment(gateway, payment) }
  rescue Payments::NotConfigured
    Rails.logger.info '[RefundSyncJob] payment gateway not configured; skipped'
  ensure
    self.class.set(wait: INTERVAL).perform_later
  end

  private

  def open_payments_on_finished_reservations
    Payment.joins(:reservation)
           .where(status: Payment::OPEN, updated_at: OPEN_PAYMENT_WINDOW.ago..)
           .where(reservations: { status: FINISHED_RESERVATION_STATUSES })
           .order(:updated_at).limit(BATCH_SIZE).to_a
  end

  def sync_refund(gateway, refund)
    result = gateway.fetch_refund(refund.gateway_refund_id)
    unless result.success?
      Rails.logger.warn "[RefundSyncJob] could not fetch refund #{refund.gateway_refund_id}"
      return
    end

    Payments::ApplyStatus.new(refund.payment, { id: refund.payment.gateway_payment_id,
                                                refund_id: refund.gateway_refund_id,
                                                status: result.data[:status] }).call
  rescue StandardError => e
    Rails.logger.error "[RefundSyncJob] refund #{refund.gateway_refund_id} failed to sync (#{e.class})"
  end

  def sync_payment(gateway, payment)
    result = gateway.fetch_payment(payment.gateway_payment_id, sync: true)
    unless result.success?
      Rails.logger.warn "[RefundSyncJob] could not fetch payment #{payment.gateway_payment_id}"
      return
    end

    Payments::ApplyStatus.new(payment, result.data).call
  rescue StandardError => e
    Rails.logger.error "[RefundSyncJob] payment #{payment.gateway_payment_id} failed to sync (#{e.class})"
  end
end

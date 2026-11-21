# frozen_string_literal: true

# Polls the gateway for refunds still pending (a missed refund webhook would leave them pending
# forever) and applies the reported status through Payments::ApplyStatus, which moves it forward only.
#
# Self-rescheduling: every run queues the next one INTERVAL later, also when the run fails, and a
# failed run is discarded rather than retried so a retry cannot start a second chain. Start the
# chain once with `bin/rails payments:start_refund_sync`. Runs are idempotent, so an accidental
# second chain only adds gateway calls; it cannot change a refund twice.
class RefundSyncJob < ApplicationJob
  queue_as :default

  INTERVAL = 10.minutes
  MIN_AGE = 1.minute

  discard_on StandardError

  def perform
    gateway = Payments::Gateway.current
    Refund.includes(:payment).where(status: 'pending').where.not(gateway_refund_id: nil)
          .where(created_at: ..MIN_AGE.ago).find_each { |refund| sync(gateway, refund) }
  rescue Payments::NotConfigured
    Rails.logger.info '[RefundSyncJob] payment gateway not configured; skipped'
  ensure
    self.class.set(wait: INTERVAL).perform_later
  end

  private

  def sync(gateway, refund)
    result = gateway.fetch_refund(refund.gateway_refund_id)
    unless result.success?
      Rails.logger.warn "[RefundSyncJob] could not fetch refund #{refund.gateway_refund_id}"
      return
    end

    Payments::ApplyStatus.new(refund.payment, { id: refund.payment.gateway_payment_id,
                                                refund_id: refund.gateway_refund_id,
                                                status: result.data[:status] }).call
  end
end

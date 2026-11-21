# frozen_string_literal: true

module Payments
  # Applies a payment status reported by the gateway (webhook, status sync or expiry job) to our
  # records. gateway_data is the gateway contract's payment data { id:, status:, connector:, error: },
  # or { id:, refund_id:, status: } for a refund. Returns :confirmed, :refunded_late, :failed or
  # :unchanged. Safe to call more than once with the same data.
  #
  # Runs under row locks on the reservation, then the payment (parent before child, so it cannot
  # deadlock with Reservations::Transition), so two applications of the same success cannot both
  # confirm or both refund.
  class ApplyStatus
    LATE_SUCCESS_REASON = 'late_success'
    LATE_STATES = %w[expired cancelled].freeze

    def initialize(payment, gateway_data)
      @payment = payment
      @data = gateway_data
    end

    def call
      return apply_refund if @data[:refund_id]

      reservation = @payment.reservation
      ActiveRecord::Base.transaction do
        reservation.lock!
        @payment.lock!
        already_succeeded = @payment.succeeded?
        @payment.update!(status: @data[:status].presence || @payment.status,
                         connector: @data[:connector].presence || @payment.connector,
                         last_error: @data[:error])
        outcome(reservation, already_succeeded)
      end
    end

    private

    def outcome(reservation, already_succeeded)
      return :failed if @payment.status == 'failed'
      return :unchanged unless @payment.succeeded?

      if reservation.pending_payment?
        confirmed = Reservations::Transition.call(reservation, to: :confirmed, from: :pending_payment,
                                                               reason: 'payment_succeeded')
        return confirmed ? :confirmed : :unchanged
      end
      # A payment that was already succeeded was handled when it first succeeded: it either
      # confirmed the reservation (whose cancel refunds it) or was refunded then.
      return :unchanged if already_succeeded || !LATE_STATES.include?(reservation.status)
      return :unchanged if @payment.refunds.exists?

      refund_late
    end

    # The gateway call runs under the payment lock on purpose: it is the only guard against a
    # second concurrent refund. A refused refund is stored as failed for an admin retry.
    def refund_late
      result = Gateway.current.create_refund(payment_id: @payment.gateway_payment_id,
                                             amount_minor: @payment.amount_minor, reason: LATE_SUCCESS_REASON)
      attributes = { amount_minor: @payment.amount_minor, reason: LATE_SUCCESS_REASON }
      if result.success?
        @payment.refunds.create!(attributes.merge(gateway_refund_id: result.data[:id],
                                                  status: result.data[:status].presence || 'pending'))
      else
        @payment.refunds.create!(attributes.merge(status: 'failed', last_error: result.error))
      end
      Rails.logger.info "[Payments::ApplyStatus] late success refunded for payment #{@payment.gateway_payment_id}"
      :refunded_late
    end

    def apply_refund
      refund = @payment.refunds.find_by(gateway_refund_id: @data[:refund_id])
      if refund
        refund.update!(status: @data[:status]) if @data[:status].present?
      else
        Rails.logger.info "[Payments::ApplyStatus] unknown refund #{@data[:refund_id]} for payment " \
                          "#{@payment.gateway_payment_id}"
      end
      :unchanged
    end
  end
end

# frozen_string_literal: true

module Payments
  # Creates a gateway payment for a reservation's fare snapshot and stores it as a Payment row.
  # Used when the seat is first held and again when the rider retries a failed payment.
  # Returns the gateway's Payments::Result; a missing gateway setup is a failed result too.
  class Start
    GATEWAY = 'hyperswitch'
    DEFAULT_FRONTEND_URL = 'http://localhost:3001'

    def initialize(reservation)
      @reservation = reservation
    end

    def call
      result = Gateway.current.create_payment(
        amount_minor: @reservation.fare_amount_minor,
        currency: @reservation.currency,
        reference: @reservation.uid,
        customer_email: @reservation.user.email,
        return_url: return_url
      )
      store(result) if result.success?
      result
    rescue NotConfigured => e
      Result.new(success: false, error: e.message)
    end

    private

    def store(result)
      @reservation.payments.create!(
        gateway: GATEWAY,
        gateway_payment_id: result.data[:id],
        status: result.data[:status],
        amount_minor: @reservation.fare_amount_minor,
        currency: @reservation.currency
      )
    end

    def return_url
      base = ENV.fetch('APP_FRONTEND_URL', DEFAULT_FRONTEND_URL)
      "#{base}/employee/reservations/#{@reservation.uid}/result"
    end
  end
end

# frozen_string_literal: true

module Payments
  # The payment gateway contract. Every gateway (Payments::Hyperswitch, FakeGateway in specs)
  # implements these methods. All amounts are in minor units. Each call returns a Payments::Result
  # (success?, data Hash, error String|nil) and never raises for API errors.
  #
  #   create_payment(amount_minor:, currency:, reference:, customer_email:, return_url:)
  #     # data: { id:, client_secret:, status: }
  #   fetch_payment(id, sync: false)                     # data: { id:, status:, connector:, error: }
  #   cancel_payment(id)                                 # data: { id:, status: }
  #   create_refund(payment_id:, amount_minor:, reason:) # data: { id:, status: }
  #   fetch_refund(id)                                   # data: { id:, status: }
  #   verify_webhook(raw_body:, headers:) -> Boolean
  module Gateway
    class << self
      # Specs set a fake here; nil goes back to the configured gateway.
      attr_writer :current

      def current
        return @current if @current
        url = ENV['HYPERSWITCH_URL']
        raise NotConfigured, 'HYPERSWITCH_URL is not set' if url.blank?

        Payments::Hyperswitch.new(
          base_url: url,
          api_key: ENV.fetch('HYPERSWITCH_API_KEY'),
          profile_id: ENV.fetch('HYPERSWITCH_PROFILE_ID'),
          webhook_secret: ENV.fetch('HYPERSWITCH_WEBHOOK_SECRET')
        )
      rescue KeyError => e
        raise NotConfigured, "#{e.key} is not set"
      end
    end
  end
end

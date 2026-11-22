# frozen_string_literal: true

module Payments
  # Raised by Payments::Gateway.current when no payment gateway is set up (HYPERSWITCH_URL unset).
  class NotConfigured < StandardError; end
end

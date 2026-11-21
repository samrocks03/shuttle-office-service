# frozen_string_literal: true

require 'net/http'
require 'json'
require 'openssl'

module Payments
  # Hyperswitch gateway client. Implements the payment gateway contract; every call returns a
  # Payments::Result and never raises for API, timeout or network errors.
  class Hyperswitch
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 10
    SIGNATURE_HEADER = 'x-webhook-signature-512'
    CANCELLATION_REASON = 'reservation_cancelled'

    # SystemCallError covers every Errno (ECONNREFUSED, ECONNRESET, EHOSTUNREACH, ETIMEDOUT, EPIPE, ...).
    NETWORK_ERRORS = [
      EOFError, IOError, Net::HTTPBadResponse, Net::ProtocolError, SocketError, SystemCallError,
      Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Timeout::Error, OpenSSL::SSL::SSLError
    ].freeze

    def initialize(base_url:, api_key:, profile_id:, webhook_secret:)
      @base_url = base_url.to_s.chomp('/')
      @api_key = api_key
      @profile_id = profile_id
      @webhook_secret = webhook_secret
    end

    def create_payment(amount_minor:, currency:, reference:, customer_email:, return_url:)
      body = {
        amount: amount_minor, currency: currency, confirm: false, capture_method: 'automatic',
        profile_id: @profile_id, email: customer_email, return_url: return_url,
        metadata: { reservation_uid: reference }
      }
      call(:post, '/payments', body) do |json|
        { id: json['payment_id'], client_secret: json['client_secret'], status: json['status'] }
      end
    end

    def fetch_payment(id, sync: false)
      path = "/payments/#{id}"
      path += '?force_sync=true' if sync
      call(:get, path) do |json|
        {
          id: json['payment_id'], status: json['status'], connector: json['connector'],
          error: json['error_message'].presence || json['error_code'].presence
        }
      end
    end

    def cancel_payment(id)
      call(:post, "/payments/#{id}/cancel", { cancellation_reason: CANCELLATION_REASON }) do |json|
        { id: json['payment_id'], status: json['status'] }
      end
    end

    def create_refund(payment_id:, amount_minor:, reason:)
      body = { payment_id: payment_id, amount: amount_minor, reason: reason }
      call(:post, '/refunds', body) { |json| refund_data(json) }
    end

    def fetch_refund(id)
      call(:get, "/refunds/#{id}") { |json| refund_data(json) }
    end

    # headers may use any key casing (also Rack-style HTTP_X_WEBHOOK_SIGNATURE_512).
    def verify_webhook(raw_body:, headers:)
      provided = signature_from(headers)
      return false if provided.blank? || @webhook_secret.blank?

      expected = OpenSSL::HMAC.hexdigest('SHA512', @webhook_secret, raw_body.to_s)
      ActiveSupport::SecurityUtils.secure_compare(expected, provided.to_s.strip.downcase)
    end

    private

    def refund_data(json)
      { id: json['refund_id'], status: json['status'] }
    end

    def signature_from(headers)
      return nil unless headers.respond_to?(:each)

      headers.each do |key, value|
        normalized = key.to_s.downcase.tr('_', '-').delete_prefix('http-')
        return value if normalized == SIGNATURE_HEADER
      end
      nil
    end

    def call(method, path, body = nil)
      response = perform(method, URI("#{@base_url}#{path}"), body)
      json = parse(response.body)

      if response.is_a?(Net::HTTPSuccess)
        return failure('Hyperswitch returned an invalid response') unless json.is_a?(Hash)

        Result.new(success: true, data: yield(json))
      else
        failure(error_message(json) || "Hyperswitch request failed (HTTP #{response.code})")
      end
    rescue *NETWORK_ERRORS => e
      # Only the class name: the exception message could echo request details.
      failure("Hyperswitch request failed (#{e.class})")
    end

    def perform(method, uri, body)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.request(build_request(method, uri, body))
    end

    def build_request(method, uri, body)
      request = (method == :post ? Net::HTTP::Post : Net::HTTP::Get).new(uri.request_uri)
      request['api-key'] = @api_key
      request['Accept'] = 'application/json'
      if body
        request['Content-Type'] = 'application/json'
        request.body = body.to_json
      end
      request
    end

    def parse(raw)
      JSON.parse(raw.to_s)
    rescue JSON::ParserError
      nil
    end

    def error_message(json)
      error = json.is_a?(Hash) ? json['error'] : nil
      message = error.is_a?(Hash) ? error['message'] : error
      message.presence if message.is_a?(String)
    end

    def failure(message)
      Result.new(success: false, error: message)
    end
  end
end

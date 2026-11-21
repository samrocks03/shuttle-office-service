# frozen_string_literal: true

module Api
  module V1
    # Receives Hyperswitch webhooks. No JWT: the HMAC-SHA512 signature over the raw body is the
    # authentication. Each event_id is handled once. Only event_id, event_type and the payment id are
    # ever logged, never the body.
    class WebhooksController < ApplicationController
      skip_before_action :authenticate

      GATEWAY = 'hyperswitch'

      def hyperswitch
        raw_body = request.raw_post
        return head :unauthorized unless Payments::Gateway.current.verify_webhook(raw_body: raw_body,
                                                                                  headers: request.headers)

        event = parse(raw_body)
        return head :bad_request unless event

        outcome = ActiveRecord::Base.transaction { record_and_apply(event) }
        log(event, outcome)
        head :ok
      rescue ActiveRecord::RecordNotUnique
        log(event, :duplicate)
        head :ok
      end

      private

      def parse(raw_body)
        json = JSON.parse(raw_body)
        return nil unless json.is_a?(Hash) && json['event_id'].present? && json['event_type'].present?

        object = json.dig('content', 'object')
        { id: json['event_id'], type: json['event_type'], content_type: json.dig('content', 'type'),
          object: object.is_a?(Hash) ? object : {} }
      rescue JSON::ParserError
        nil
      end

      # Stored first, in the same transaction as the work: a duplicate event_id raises here, and if
      # applying fails the event is not stored, so the gateway's retry is handled.
      def record_and_apply(event)
        return :duplicate if PaymentWebhookEvent.exists?(event_id: event[:id])

        PaymentWebhookEvent.create!(gateway: GATEWAY, event_id: event[:id], event_type: event[:type],
                                    gateway_payment_id: event[:object]['payment_id'], received_at: Time.current)
        data = gateway_data(event)
        return :ignored unless data

        payment = Payment.find_by(gateway: GATEWAY, gateway_payment_id: data[:id])
        return :unknown_payment unless payment

        Payments::ApplyStatus.new(payment, data).call
      end

      def gateway_data(event)
        object = event[:object]
        case event[:content_type]
        when 'payment_details'
          { id: object['payment_id'], status: object['status'], connector: object['connector'],
            error: object['error_message'].presence || object['error_code'].presence }
        when 'refund_details'
          { id: object['payment_id'], refund_id: object['refund_id'], status: object['status'] }
        end
      end

      def log(event, outcome)
        Rails.logger.info "[Webhooks::Hyperswitch] event #{event&.dig(:id)} (#{event&.dig(:type)}) " \
                          "payment #{event&.dig(:object, 'payment_id')}: #{outcome.to_s.tr('_', ' ')}"
      end
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Webhooks', type: :request do
  include ActiveJob::TestHelper

  let(:gateway) { FakeGateway.new }
  let(:schedule) { create(:schedule, available_seats: 10) }
  let(:reservation) { create(:reservation, schedule: schedule, status: 'pending_payment') }
  let!(:payment) do
    create(:payment, reservation: reservation, gateway_payment_id: 'pay_abc', amount_minor: 3500)
  end

  before { Payments::Gateway.current = gateway }

  def payment_event(event_id, event_type: 'payment_succeeded', status: 'succeeded', payment_id: 'pay_abc')
    {
      event_id: event_id, event_type: event_type,
      content: {
        type: 'payment_details',
        object: { payment_id: payment_id, status: status, connector: 'stripe', error_message: nil }
      }
    }.to_json
  end

  def refund_event(event_id, refund_id:, status:)
    {
      event_id: event_id, event_type: "refund_#{status}",
      content: { type: 'refund_details', object: { payment_id: 'pay_abc', refund_id: refund_id, status: status } }
    }.to_json
  end

  def deliver(body, headers: {})
    post '/api/v1/webhooks/hyperswitch', params: body,
                                         headers: { 'Content-Type' => 'application/json' }.merge(headers)
  end

  describe 'payment_succeeded' do
    it 'confirms the reservation, queues one email and stores the event' do
      expect { deliver(payment_event('evt_1')) }
        .to have_enqueued_job(ReservationConfirmationJob).with(reservation.id).exactly(:once)

      expect(response).to have_http_status(:ok)
      expect(reservation.reload.status).to eq('confirmed')
      expect(payment.reload.status).to eq('succeeded')
      expect(PaymentWebhookEvent.sole).to have_attributes(
        gateway: 'hyperswitch', event_id: 'evt_1', event_type: 'payment_succeeded', gateway_payment_id: 'pay_abc'
      )
    end

    it 'handles the same event only once' do
      expect do
        deliver(payment_event('evt_1'))
        deliver(payment_event('evt_1'))
      end.to have_enqueued_job(ReservationConfirmationJob).exactly(:once)

      expect(response).to have_http_status(:ok)
      expect(PaymentWebhookEvent.count).to eq(1)
    end

    it 'sends no second email for a new succeeded event on a confirmed reservation' do
      deliver(payment_event('evt_1'))

      expect { deliver(payment_event('evt_2')) }.not_to have_enqueued_job(ReservationConfirmationJob)
      expect(response).to have_http_status(:ok)
      expect(reservation.reload.status).to eq('confirmed')
    end

    it 'refunds a success that arrives after the hold expired, once' do
      reservation.update!(status: 'expired')

      deliver(payment_event('evt_1'))
      deliver(payment_event('evt_2'))

      expect(response).to have_http_status(:ok)
      expect(gateway.calls[:create_refund]).to eq([{ payment_id: 'pay_abc', amount_minor: 3500,
                                                     reason: 'late_success' }])
      expect(payment.refunds.sole).to have_attributes(reason: 'late_success', amount_minor: 3500)
      expect(reservation.reload.status).to eq('expired')
    end
  end

  it 'keeps the reservation pending_payment on payment_failed' do
    deliver(payment_event('evt_1', event_type: 'payment_failed', status: 'failed'))

    expect(response).to have_http_status(:ok)
    expect(payment.reload.status).to eq('failed')
    expect(reservation.reload.status).to eq('pending_payment')
  end

  it 'sets the refund status on refund_succeeded' do
    refund = payment.refunds.create!(gateway_refund_id: 'ref_xyz', amount_minor: 3500, status: 'pending',
                                     reason: 'reservation_cancelled')

    deliver(refund_event('evt_r1', refund_id: 'ref_xyz', status: 'succeeded'))

    expect(response).to have_http_status(:ok)
    expect(refund.reload.status).to eq('succeeded')
  end

  it 'returns 200 and logs an event for an unknown payment' do
    allow(Rails.logger).to receive(:info).and_call_original

    deliver(payment_event('evt_1', payment_id: 'pay_unknown'))

    expect(response).to have_http_status(:ok)
    expect(Rails.logger).to have_received(:info).with(/evt_1.*pay_unknown.*unknown payment/)
    expect(reservation.reload.status).to eq('pending_payment')
  end

  it 'keeps the event content out of the logged parameters' do
    deliver(payment_event('evt_1'))

    expect(request.filtered_parameters['content']).to eq('[FILTERED]')
  end

  describe 'signature check' do
    let(:secret) { 'whsec_spec_only' }
    let(:gateway) do
      Payments::Hyperswitch.new(base_url: 'https://hyperswitch.test', api_key: 'k', profile_id: 'p',
                                webhook_secret: secret)
    end

    def signature(body)
      OpenSSL::HMAC.hexdigest('SHA512', secret, body)
    end

    it 'accepts a correctly signed body' do
      body = payment_event('evt_1', event_type: 'payment_processing', status: 'processing')

      deliver(body, headers: { 'x-webhook-signature-512' => signature(body) })

      expect(response).to have_http_status(:ok)
      expect(payment.reload.status).to eq('processing')
    end

    it 'rejects a bad signature with 401 and stores nothing' do
      body = payment_event('evt_1')

      expect { deliver(body, headers: { 'x-webhook-signature-512' => signature("#{body} ") }) }
        .not_to have_enqueued_job(ReservationConfirmationJob)

      expect(response).to have_http_status(:unauthorized)
      expect(PaymentWebhookEvent.count).to eq(0)
      expect(payment.reload.status).to eq('requires_payment_method')
      expect(reservation.reload.status).to eq('pending_payment')
    end

    it 'rejects a missing signature with 401' do
      deliver(payment_event('evt_1'))

      expect(response).to have_http_status(:unauthorized)
      expect(PaymentWebhookEvent.count).to eq(0)
    end
  end
end

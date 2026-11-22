# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Reservation payment status and retry', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:gateway) { FakeGateway.new }
  let(:user) { create(:user, role: create(:role, :user_role)) }
  let(:headers) { auth_headers(user) }
  let(:schedule) { create(:schedule, available_seats: 40) }
  let(:hold_expires_at) { 6.minutes.from_now.change(usec: 0) }
  let!(:reservation) do
    create(:reservation, user: user, schedule: schedule, status: 'pending_payment', fare_amount_minor: 3500,
                         currency: 'INR', hold_expires_at: hold_expires_at)
  end
  let!(:payment) do
    create(:payment, reservation: reservation, gateway_payment_id: 'pay_first', amount_minor: 3500,
                     status: 'requires_payment_method')
  end

  before do
    Payments::Gateway.current = gateway
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('HYPERSWITCH_PUBLISHABLE_KEY').and_return('pk_test_fake')
  end

  def payment_path(record = reservation)
    "/api/v1/reservations/#{record.uid}/payment.json"
  end

  def gateway_reports(status, connector: nil, error: nil)
    allow(gateway).to receive(:fetch_payment) do |id, sync: false|
      gateway.calls[:fetch_payment] << { id: id, sync: sync }
      Payments::Result.new(success: true, data: { id: id, status: status, connector: connector, error: error })
    end
  end

  describe 'GET /api/v1/reservations/:id/payment' do
    it 'syncs a pending reservation with the gateway and reports it confirmed once paid' do
      gateway_reports('succeeded', connector: 'razorpay')

      get payment_path, headers: headers

      expect(response).to have_http_status(:ok)
      expect(gateway.calls[:fetch_payment]).to eq([{ id: 'pay_first', sync: true }])
      expect(json_response['success']).to be true
      expect(json_response['data']).to include('status' => 'confirmed', 'payment_status' => 'succeeded',
                                               'connector' => 'razorpay')
      expect(reservation.reload).to be_confirmed
      expect(payment.reload.status).to eq('succeeded')
    end

    it 'reports the stored state and the hold expiry while the payment is still open' do
      get payment_path, headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include('status' => 'pending_payment',
                                               'payment_status' => 'requires_payment_method',
                                               'connector' => nil)
      expect(Time.zone.parse(json_response['data']['hold_expires_at'])).to eq(hold_expires_at)
    end

    it 'reports a failed payment after syncing it' do
      gateway_reports('failed', error: 'card declined')

      get payment_path, headers: headers

      expect(json_response['data']).to include('status' => 'pending_payment', 'payment_status' => 'failed')
      expect(response.body).not_to include('card declined')
    end

    it 'syncs only the latest payment' do
      payment.update!(status: 'failed')
      create(:payment, reservation: reservation, gateway_payment_id: 'pay_second', amount_minor: 3500)

      get payment_path, headers: headers

      expect(gateway.calls[:fetch_payment].map { |call| call[:id] }).to eq(['pay_second'])
    end

    it 'does not call the gateway for a reservation that is no longer pending' do
      reservation.update!(status: 'confirmed')
      payment.update!(status: 'succeeded')

      get payment_path, headers: headers

      expect(response).to have_http_status(:ok)
      expect(gateway.calls[:fetch_payment]).to be_empty
      expect(json_response['data']).to include('status' => 'confirmed', 'payment_status' => 'succeeded')
    end

    it 'still answers with the stored state when the gateway call fails' do
      allow(gateway).to receive(:fetch_payment)
        .and_return(Payments::Result.new(success: false, error: 'connector timed out (raw gateway text)'))

      get payment_path, headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include('status' => 'pending_payment',
                                               'payment_status' => 'requires_payment_method')
      expect(response.body).not_to include('raw gateway text')
    end

    it 'still answers with the stored state when no gateway is configured' do
      Payments::Gateway.current = nil
      allow(ENV).to receive(:[]).with('HYPERSWITCH_URL').and_return(nil)

      get payment_path, headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include('status' => 'pending_payment')
    end

    it "returns 404 for another user's reservation" do
      get payment_path, headers: auth_headers(create(:user, role: create(:role, :user_role)))

      expect(response).to have_http_status(:not_found)
      expect(json_response['error_key']).to eq('reservation.not_found')
      expect(gateway.calls[:fetch_payment]).to be_empty
    end

    it 'lets an admin read any reservation' do
      get payment_path, headers: auth_headers(create(:user, role: create(:role, :admin)))

      expect(response).to have_http_status(:ok)
    end

    it 'returns 401 without a token' do
      get payment_path

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/reservations/:id/payment' do
    def retry_payment(record = reservation, as: headers)
      post payment_path(record), headers: as
    end

    context 'when the latest payment failed' do
      before { payment.update!(status: 'failed') }

      it 'starts a new payment, returns its secret and keeps the hold time' do
        expect { retry_payment }.to change { reservation.payments.count }.from(1).to(2)

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['data']).to eq('client_secret' => 'pay_fake_1_secret_fake',
                                            'publishable_key' => 'pk_test_fake')
        expect(reservation.payments.order(:id).last.gateway_payment_id).to eq('pay_fake_1')
        expect(reservation.reload.hold_expires_at).to eq(hold_expires_at)
        expect(reservation).to be_pending_payment
        expect(payment.reload.status).to eq('failed')
      end

      it 'then makes the new payment the latest one that status reads' do
        retry_payment
        get payment_path, headers: headers

        expect(gateway.calls[:fetch_payment].map { |call| call[:id] }).to eq(['pay_fake_1'])
        expect(json_response['data']['payment_status']).to eq('requires_payment_method')
      end

      it 'allows a rider to retry again after the new payment fails too' do
        retry_payment
        reservation.payments.order(:id).last.update!(status: 'failed')

        expect { retry_payment }.to change { reservation.payments.count }.by(1)
        expect(response).to have_http_status(:ok)
      end

      it 'does not start a second payment while the first retry is still open' do
        retry_payment

        expect { retry_payment }.not_to(change { reservation.payments.count })
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error_key']).to eq('reservation.retry_not_allowed')
        expect(gateway.calls[:create_payment].size).to eq(1)
      end

      it 'returns 422 payment_start_failed and keeps the reservation pending when the gateway fails' do
        gateway.fail_create = true

        expect { retry_payment }.not_to(change { reservation.payments.count })

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error_key']).to eq('reservation.payment_start_failed')
        expect(response.body).not_to include('raw gateway text')
        expect(reservation.reload).to be_pending_payment
        expect(schedule.reload.available_seats).to eq(40)
      end

      it 'returns 422 payment_start_failed when no gateway is configured' do
        Payments::Gateway.current = nil
        allow(ENV).to receive(:[]).with('HYPERSWITCH_URL').and_return(nil)

        retry_payment

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error_key']).to eq('reservation.payment_start_failed')
        expect(reservation.reload).to be_pending_payment
      end
    end

    it 'allows a retry after a cancelled payment' do
      payment.update!(status: 'cancelled')

      retry_payment

      expect(response).to have_http_status(:ok)
      expect(reservation.payments.count).to eq(2)
    end

    %w[processing requires_payment_method requires_customer_action succeeded].each do |status|
      it "returns 422 retry_not_allowed while the latest payment is #{status}" do
        payment.update!(status: status)

        expect { retry_payment }.not_to(change { reservation.payments.count })

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error_key']).to eq('reservation.retry_not_allowed')
        expect(gateway.calls[:create_payment]).to be_empty
      end
    end

    it 'returns 422 retry_not_allowed after the hold has expired' do
      payment.update!(status: 'failed')

      travel_to(hold_expires_at + 1.second) do
        expect { retry_payment }.not_to(change { reservation.payments.count })
      end

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error_key']).to eq('reservation.retry_not_allowed')
    end

    it 'returns 422 retry_not_allowed at the exact hold expiry time' do
      payment.update!(status: 'failed')

      travel_to(hold_expires_at) { retry_payment }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    %w[confirmed cancelled expired].each do |status|
      it "returns 422 retry_not_allowed when the reservation is #{status}" do
        payment.update!(status: 'failed')
        reservation.update!(status: status)

        retry_payment

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error_key']).to eq('reservation.retry_not_allowed')
        expect(reservation.payments.count).to eq(1)
      end
    end

    it 'returns 422 retry_not_allowed for a reservation without any payment' do
      payment.destroy!

      retry_payment

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error_key']).to eq('reservation.retry_not_allowed')
    end

    it "returns 404 for another user's reservation and starts nothing" do
      payment.update!(status: 'failed')

      retry_payment(as: auth_headers(create(:user, role: create(:role, :user_role))))

      expect(response).to have_http_status(:not_found)
      expect(json_response['error_key']).to eq('reservation.not_found')
      expect(gateway.calls[:create_payment]).to be_empty
    end
  end
end

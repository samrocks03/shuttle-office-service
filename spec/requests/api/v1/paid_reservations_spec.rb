# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Reservations (paid)', type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:gateway) { FakeGateway.new }
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:city) { create(:city, payments_enabled: true, time_zone: 'Asia/Kolkata') }
  let(:company) { create(:company, city: city) }
  let(:bus) { create(:bus, company: company, service_class: 'ac', capacity: 40) }
  let(:from_stop) { create(:stop, city: city) }
  let(:to_stop) { create(:stop, :office, city: city) }
  let(:schedule) do
    create(:schedule, bus: bus, available_seats: 40, from_stop: from_stop, to_stop: to_stop)
  end

  before do
    Payments::Gateway.current = gateway
    create(:stop_distance, from_stop: from_stop, to_stop: to_stop, computed_km: 18.4)
    create(:fare_table, :best_ac, city: city)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('HYPERSWITCH_PUBLISHABLE_KEY').and_return('pk_test_fake')
  end

  def book
    post '/api/v1/reservations.json', params: { reservation: { schedule_id: schedule.id } }.to_json,
                                      headers: headers
  end

  def cancel(reservation)
    delete "/api/v1/reservations/#{reservation.uid}.json", headers: headers
  end

  def attributes
    json_response.dig('data', 'attributes')
  end

  describe 'POST /api/v1/reservations' do
    it 'holds the seat as pending_payment with the fare and returns the payment secret' do
      expect { book }.not_to have_enqueued_job(ReservationConfirmationJob)

      expect(response).to have_http_status(:created)
      expect(attributes['status']).to eq('pending_payment')
      expect(attributes.dig('fare', 'amount_minor')).to eq(3500)
      expect(attributes.dig('fare', 'currency')).to eq('INR')
      expect(attributes['hold_expires_at']).to be_present
      expect(json_response.dig('payment', 'client_secret')).to be_present
      expect(json_response.dig('payment', 'publishable_key')).to eq('pk_test_fake')
      expect(schedule.reload.available_seats).to eq(39)
    end

    it 'saves the fare snapshot, the hold time and a payment row' do
      freeze_time do
        book

        reservation = Reservation.find_by!(uid: attributes['uid'])
        expect(reservation).to have_attributes(
          fare_amount_minor: 3500, currency: 'INR', hold_expires_at: Time.current + Reservation::HOLD_DURATION
        )
        expect(reservation.fare_breakdown).to include('slab_label' => 'up to 20 km')
        expect(reservation.payments.sole).to have_attributes(
          gateway: 'hyperswitch', gateway_payment_id: 'pay_fake_1', status: 'requires_payment_method',
          amount_minor: 3500, currency: 'INR'
        )
      end
    end

    it 'asks the gateway for the fare, with the reservation uid and the result page' do
      book

      uid = attributes['uid']
      expect(gateway.calls[:create_payment]).to eq([{
                                                     amount_minor: 3500, currency: 'INR', reference: uid,
                                                     customer_email: user.email,
                                                     return_url: "http://localhost:3001/employee/reservations/#{uid}/result"
                                                   }])
    end

    it 'schedules the hold expiry job at hold_expires_at' do
      freeze_time do
        book

        expect(ReservationHoldExpiryJob).to have_been_enqueued
          .with(Reservation.sole.id)
          .at(Time.current + Reservation::HOLD_DURATION)
      end
    end

    it 'refuses a schedule that cannot be priced, without taking a seat' do
      StopDistance.delete_all

      expect { book }.not_to change(Reservation, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error_key']).to eq('reservation.not_priced')
      expect(json_response.dig('errors', 'base').first).to include('distance')
      expect(schedule.reload.available_seats).to eq(40)
      expect(gateway.calls[:create_payment]).to be_empty
    end

    it 'gives the seat back and expires the hold when the gateway fails' do
      gateway.fail_create = true

      book

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error_key']).to eq('reservation.payment_start_failed')
      expect(response.body).not_to include('raw gateway text')
      expect(schedule.reload.available_seats).to eq(40)
      expect(Reservation.sole.status).to eq('expired')
      expect(Payment.count).to eq(0)
    end

    it 'gives the seat back when no gateway is configured' do
      Payments::Gateway.current = nil
      allow(ENV).to receive(:[]).with('HYPERSWITCH_URL').and_return(nil)

      book

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error_key']).to eq('reservation.payment_start_failed')
      expect(schedule.reload.available_seats).to eq(40)
      expect(Reservation.sole.status).to eq('expired')
    end
  end

  describe 'DELETE /api/v1/reservations/:id' do
    def hold!(status:, payment_status:)
      reservation = create(:reservation, user: user, schedule: schedule, status: status,
                                         fare_amount_minor: 3500, currency: 'INR',
                                         hold_expires_at: 10.minutes.from_now)
      schedule.decrement_available_seat!
      create(:payment, reservation: reservation, gateway_payment_id: 'pay_held', status: payment_status,
                       amount_minor: 3500)
      reservation
    end

    context 'when the reservation is pending_payment' do
      let!(:reservation) { hold!(status: 'pending_payment', payment_status: 'requires_payment_method') }

      it 'cancels it, cancels the open payment and gives the seat back' do
        cancel(reservation)

        expect(response).to have_http_status(:ok)
        expect(attributes['status']).to eq('cancelled')
        expect(reservation.reload).to be_cancelled
        expect(gateway.calls[:cancel_payment]).to eq(['pay_held'])
        expect(reservation.payments.sole.status).to eq('cancelled')
        expect(schedule.reload.available_seats).to eq(40)
        expect(Refund.count).to eq(0)
      end

      it 'still cancels when the gateway refuses, and records the error on the payment' do
        gateway.fail_cancel = true

        cancel(reservation)

        expect(response).to have_http_status(:ok)
        expect(reservation.reload).to be_cancelled
        expect(reservation.payments.sole).to have_attributes(status: 'requires_payment_method',
                                                             last_error: 'cancel rejected by connector')
        expect(response.body).not_to include('cancel rejected by connector')
      end

      it 'refunds a payment the cancel response reports as succeeded, through ApplyStatus' do
        allow(gateway).to receive(:cancel_payment)
          .and_return(Payments::Result.new(success: true, data: { id: 'pay_held', status: 'succeeded' }))

        cancel(reservation)

        expect(response).to have_http_status(:ok)
        expect(reservation.reload).to be_cancelled
        expect(reservation.payments.sole.status).to eq('succeeded')
        expect(Refund.sole).to have_attributes(reason: 'late_success', amount_minor: 3500)
        expect(schedule.reload.available_seats).to eq(40)
      end
    end

    context 'when the reservation is confirmed and paid' do
      let!(:reservation) { hold!(status: 'confirmed', payment_status: 'succeeded') }

      it 'cancels before departure and refunds the full amount' do
        cancel(reservation)

        expect(response).to have_http_status(:ok)
        expect(attributes['status']).to eq('cancelled')
        expect(schedule.reload.available_seats).to eq(40)
        expect(gateway.calls[:create_refund]).to eq([{ payment_id: 'pay_held', amount_minor: 3500,
                                                       reason: 'reservation_cancelled' }])
        expect(Refund.sole).to have_attributes(amount_minor: 3500, status: 'pending', gateway_refund_id: 'ref_fake_1',
                                               payment_id: reservation.payments.sole.id)
      end

      it 'stores the refund status the gateway returns' do
        gateway.refund_status = 'succeeded'

        cancel(reservation)

        expect(Refund.sole.status).to eq('succeeded')
      end

      it 'keeps the reservation cancelled and stores a failed refund when the refund call fails' do
        gateway.fail_refund = true

        cancel(reservation)

        expect(response).to have_http_status(:ok)
        expect(reservation.reload).to be_cancelled
        expect(Refund.sole).to have_attributes(status: 'failed', amount_minor: 3500,
                                               last_error: 'refund rejected by connector')
        expect(response.body).not_to include('refund rejected by connector')
      end

      it 'logs a failed refund as an error, with ids only' do
        gateway.fail_refund = true
        allow(Rails.logger).to receive(:error)

        cancel(reservation)

        expect(Rails.logger).to have_received(:error).with(/refund FAILED for payment pay_held/)
        expect(Rails.logger).not_to have_received(:error).with(/rejected by connector/)
      end

      it 'refunds every succeeded payment when the rider was charged twice' do
        create(:payment, reservation: reservation, gateway_payment_id: 'pay_double', status: 'succeeded',
                         amount_minor: 3500)

        cancel(reservation)

        expect(response).to have_http_status(:ok)
        expect(gateway.calls[:create_refund].pluck(:payment_id)).to contain_exactly('pay_held', 'pay_double')
        expect(Refund.count).to eq(2)
      end

      it 'does not refund a payment that already has a refund' do
        double = create(:payment, reservation: reservation, gateway_payment_id: 'pay_double', status: 'succeeded',
                                  amount_minor: 3500)
        double.refunds.create!(gateway_refund_id: 'ref_dup', amount_minor: 3500, status: 'pending',
                               reason: 'duplicate_payment')

        cancel(reservation)

        expect(gateway.calls[:create_refund].pluck(:payment_id)).to eq(['pay_held'])
        expect(Refund.count).to eq(2)
      end

      it 'refuses after departure, without a refund' do
        schedule.update_columns(date: Date.yesterday)

        cancel(reservation)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error_key']).to eq('reservation.cancel_too_late')
        expect(reservation.reload).to be_confirmed
        expect(Refund.count).to eq(0)
        expect(gateway.calls[:create_refund]).to be_empty
      end

      it 'judges departure in the city time zone' do
        kolkata = ActiveSupport::TimeZone['Asia/Kolkata']
        departure = kolkata.local(2026, 12, 1, 10, 0)
        schedule.update_columns(date: departure.to_date, departure_time: '10:00', arrival_time: '11:00')

        travel_to(departure + 1.minute) { cancel(reservation) }
        expect(json_response['error_key']).to eq('reservation.cancel_too_late')

        travel_to(departure - 1.minute) { cancel(reservation) }
        expect(response).to have_http_status(:ok)
      end

      it 'refuses a second cancel and still has exactly one refund' do
        cancel(reservation)
        cancel(reservation)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error_key']).to eq('reservation.not_cancellable')
        expect(Refund.count).to eq(1)
        expect(schedule.reload.available_seats).to eq(40)
      end
    end

    context 'when a payment confirms the hold while the cancel is in flight' do
      let!(:reservation) { hold!(status: 'pending_payment', payment_status: 'requires_payment_method') }

      # The cancel loads the reservation as pending_payment; the webhook confirms the row before
      # the cancel's Transition takes the lock.
      before do
        stale = Reservation.find(reservation.id)
        relation = instance_double(ActiveRecord::Relation, find_by: stale)
        allow(ReservationRepository).to receive(:scope_for).and_return(relation)
        reservation.update_columns(status: 'confirmed')
        reservation.payments.sole.update_columns(status: 'succeeded')
      end

      it 'cancels and refunds the full amount before departure' do
        cancel(reservation)

        expect(response).to have_http_status(:ok)
        expect(reservation.reload).to be_cancelled
        expect(Refund.sole).to have_attributes(amount_minor: 3500, status: 'pending')
        expect(gateway.calls[:create_refund].size).to eq(1)
        expect(gateway.calls[:cancel_payment]).to be_empty
        expect(schedule.reload.available_seats).to eq(40)
      end

      it 'refuses after departure and stays confirmed' do
        schedule.update_columns(date: Date.yesterday)

        cancel(reservation)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error_key']).to eq('reservation.cancel_too_late')
        expect(reservation.reload).to be_confirmed
        expect(Refund.count).to eq(0)
      end
    end

    it 'refuses an expired hold' do
      reservation = hold!(status: 'pending_payment', payment_status: 'requires_payment_method')
      Reservations::Transition.call(reservation, to: :expired, reason: 'test')

      cancel(reservation)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error_key']).to eq('reservation.not_cancellable')
      expect(Reservation.exists?(reservation.id)).to be true
    end
  end

  describe 'a company without payments' do
    before { city.update!(payments_enabled: false) }

    it 'books as before: confirmed, email queued, no gateway call' do
      expect { book }.to have_enqueued_job(ReservationConfirmationJob).exactly(:once)

      expect(response).to have_http_status(:created)
      expect(attributes['status']).to eq('confirmed')
      expect(json_response).not_to have_key('payment')
      expect(gateway.calls[:create_payment]).to be_empty
      expect(schedule.reload.available_seats).to eq(39)
    end

    it 'deletes on cancel as before' do
      book
      reservation = Reservation.sole

      cancel(reservation)

      expect(response).to have_http_status(:ok)
      expect(Reservation.exists?(reservation.id)).to be false
      expect(schedule.reload.available_seats).to eq(40)
    end
  end
end

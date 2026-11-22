# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Reservations', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:bus) { create(:bus, capacity: 40) }
  let(:schedule) { create(:schedule, bus: bus, available_seats: bus.capacity) }

  describe 'GET /api/v1/reservations' do
    before { create(:reservation, user: user, schedule: schedule) }

    it 'returns paginated reservations' do
      get '/api/v1/reservations.json', headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
    end
  end

  describe 'refund state' do
    let(:reservation) do
      create(:reservation, user: user, schedule: schedule, status: 'cancelled', fare_amount_minor: 3500, currency: 'INR')
    end

    def first_attributes
      json_response['data'].find { |row| row['attributes']['uid'] == reservation.uid }['attributes']
    end

    it 'is null when the reservation has no refund' do
      get "/api/v1/reservations/#{reservation.uid}.json", headers: headers

      expect(json_response.dig('data', 'attributes')).to include('refund' => nil)
    end

    it 'shows the latest refund status and amount in the list and on the reservation' do
      payment = create(:payment, reservation: reservation, status: 'succeeded', amount_minor: 3500)
      payment.refunds.create!(status: 'failed', amount_minor: 3500, reason: 'reservation_cancelled',
                              last_error: 'refund rejected by connector', created_at: 1.hour.ago)
      payment.refunds.create!(gateway_refund_id: 'ref_retry', status: 'pending', amount_minor: 3500,
                              reason: 'reservation_cancelled')

      get '/api/v1/reservations.json', headers: headers
      expect(first_attributes['refund']).to eq('status' => 'pending', 'amount_minor' => 3500,
                                               'reason' => 'reservation_cancelled')

      get "/api/v1/reservations/#{reservation.uid}.json", headers: headers
      expect(json_response.dig('data', 'attributes', 'refund', 'status')).to eq('pending')
      expect(response.body).not_to include('rejected by connector')
    end
  end

  describe 'GET /api/v1/reservations/:id' do
    let(:reservation) { create(:reservation, user: user, schedule: schedule) }

    it 'returns the reservation' do
      get "/api/v1/reservations/#{reservation.uid}.json", headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 for invalid uid' do
      get '/api/v1/reservations/bad.json', headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/reservations' do
    it 'creates a reservation when seats available' do
      post '/api/v1/reservations.json', params: {
        reservation: { schedule_id: schedule.id, user_id: user.id }
      }.to_json, headers: headers
      expect(response).to have_http_status(:created)
      expect(json_response['success']).to be true
    end

    it 'fails when no seats available' do
      schedule.update!(available_seats: 0)
      post '/api/v1/reservations.json', params: {
        reservation: { schedule_id: schedule.id, user_id: user.id }
      }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['success']).to be false
    end

    it 'fails for duplicate booking' do
      create(:reservation, user: user, schedule: schedule)
      post '/api/v1/reservations.json', params: {
        reservation: { schedule_id: schedule.id, user_id: user.id }
      }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /api/v1/reservations/:id' do
    let!(:reservation) do
      res = create(:reservation, user: user, schedule: schedule)
      schedule.decrement_available_seat!
      res
    end

    it 'destroys and increments seats' do
      seats_before = schedule.reload.available_seats
      delete "/api/v1/reservations/#{reservation.uid}.json", headers: headers
      expect(response).to have_http_status(:ok)
      expect(schedule.reload.available_seats).to eq(seats_before + 1)
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Schedules', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:bus) { create(:bus) }

  describe 'GET /api/v1/schedules' do
    before { create_list(:schedule, 3, bus: bus) }

    it 'returns paginated schedules' do
      get '/api/v1/schedules.json', headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['meta']).to include('total_count')
    end

    it 'filters by bus_id' do
      other_bus = create(:bus)
      create(:schedule, bus: other_bus)
      get '/api/v1/schedules.json', params: { bus_id: bus.id }, headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /api/v1/schedules/:id' do
    let(:schedule) { create(:schedule, bus: bus) }

    it 'returns the schedule' do
      get "/api/v1/schedules/#{schedule.uid}.json", headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 for invalid uid' do
      get '/api/v1/schedules/bad.json', headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/schedules' do
    it 'creates with valid future date' do
      post '/api/v1/schedules.json', params: {
        schedule: {
          start_point: 'Office', arrival_time: '10:00', departure_time: '09:00',
          date: (Date.today + 30).to_s, bus_id: bus.id
        }
      }.to_json, headers: headers
      expect(response).to have_http_status(:created)
    end

    it 'rejects past date' do
      post '/api/v1/schedules.json', params: {
        schedule: {
          start_point: 'Office', arrival_time: '10:00', departure_time: '09:00',
          date: '2020-01-01', bus_id: bus.id
        }
      }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/schedules/:id' do
    let(:schedule) { create(:schedule, bus: bus) }

    it 'updates the schedule' do
      patch "/api/v1/schedules/#{schedule.uid}.json",
            params: { schedule: { start_point: 'New Location' } }.to_json, headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'DELETE /api/v1/schedules/:id' do
    let!(:schedule) { create(:schedule, bus: bus) }

    it 'destroys the schedule' do
      delete "/api/v1/schedules/#{schedule.uid}.json", headers: headers
      expect(response).to have_http_status(:ok)
    end
  end
end

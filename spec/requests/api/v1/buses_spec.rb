# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Buses', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:company) { create(:company) }

  describe 'GET /api/v1/buses' do
    before { create_list(:bus, 3, company: company) }

    it 'returns paginated buses' do
      get '/api/v1/buses.json', headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['meta']).to include('total_count')
    end
  end

  describe 'GET /api/v1/buses/:id' do
    let(:bus) { create(:bus, company: company) }

    it 'returns the bus' do
      get "/api/v1/buses/#{bus.uid}.json", headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 for invalid uid' do
      get '/api/v1/buses/bad.json', headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/buses' do
    it 'creates a bus' do
      post '/api/v1/buses.json', params: {
        bus: { number: 'BUS-999', capacity: 40, model: 'Volvo', company_id: company.id }
      }.to_json, headers: headers
      expect(response).to have_http_status(:created)
    end

    it 'fails without required params' do
      post '/api/v1/buses.json', params: { bus: { number: '' } }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/buses/:id' do
    let(:bus) { create(:bus, company: company) }

    it 'updates the bus' do
      patch "/api/v1/buses/#{bus.uid}.json", params: { bus: { capacity: 50 } }.to_json, headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'DELETE /api/v1/buses/:id' do
    let!(:bus) { create(:bus, company: company) }

    it 'destroys the bus' do
      delete "/api/v1/buses/#{bus.uid}.json", headers: headers
      expect(response).to have_http_status(:ok)
    end
  end
end

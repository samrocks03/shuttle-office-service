# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Companies', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe 'GET /api/v1/companies' do
    before { create_list(:company, 3) }

    it 'returns paginated companies' do
      get '/api/v1/companies.json', headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['meta']).to include('total_count')
    end

    it 'supports search' do
      create(:company, name: 'UniqueCompanyXYZ', location: 'Mars')
      get '/api/v1/companies.json', params: { search: 'UniqueCompanyXYZ' }, headers: headers
      expect(json_response['data'].length).to be >= 1
    end

    it 'supports sorting' do
      get '/api/v1/companies.json', params: { sort_by: 'name', sort_order: 'desc' }, headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /api/v1/companies/:id' do
    let(:company) { create(:company) }

    it 'returns the company' do
      get "/api/v1/companies/#{company.uid}.json", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
    end

    it 'returns 404 for invalid uid' do
      get '/api/v1/companies/bad.json', headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/companies' do
    it 'creates a company with valid params' do
      post '/api/v1/companies.json', params: { company: { name: 'NewCo', location: 'Delhi' } }.to_json, headers: headers
      expect(response).to have_http_status(:created)
      expect(json_response['success']).to be true
    end

    it 'fails with invalid params' do
      post '/api/v1/companies.json', params: { company: { name: '', location: '' } }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/companies/:id' do
    let(:company) { create(:company) }

    it 'updates the company' do
      patch "/api/v1/companies/#{company.uid}.json", params: { company: { name: 'Updated' } }.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
    end
  end

  describe 'DELETE /api/v1/companies/:id' do
    let!(:company) { create(:company) }

    it 'destroys the company' do
      delete "/api/v1/companies/#{company.uid}.json", headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'returns error for nonexistent' do
      delete '/api/v1/companies/bad.json', headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end

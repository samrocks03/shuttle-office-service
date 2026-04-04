# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Roles', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe 'GET /api/v1/roles' do
    before { create_list(:role, 3) }

    it 'returns paginated roles' do
      get '/api/v1/roles.json', headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']).to be_an(Array)
      expect(json_response['meta']).to include('current_page', 'total_count')
    end

    it 'supports search' do
      create(:role, name: 'Unique SearchTerm Role')
      get '/api/v1/roles.json', params: { search: 'SearchTerm' }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to be >= 1
    end

    it 'supports pagination' do
      get '/api/v1/roles.json', params: { page: 1, per_page: 2 }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['meta']['per_page']).to eq(2)
    end
  end

  describe 'GET /api/v1/roles/:id' do
    let(:role) { create(:role) }

    it 'returns the role' do
      get "/api/v1/roles/#{role.uid}.json", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
    end

    it 'returns 404 for invalid uid' do
      get '/api/v1/roles/nonexistent.json', headers: headers
      expect(response).to have_http_status(:not_found)
      expect(json_response['success']).to be false
    end
  end

  describe 'POST /api/v1/roles' do
    context 'with valid params' do
      it 'creates a role' do
        post '/api/v1/roles.json', params: { role: { name: 'Manager', role_type: 'user' } }.to_json, headers: headers
        expect(response).to have_http_status(:created)
        expect(json_response['success']).to be true
      end
    end

    context 'with invalid params' do
      it 'returns errors' do
        post '/api/v1/roles.json', params: { role: { name: '', role_type: '' } }.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'PATCH /api/v1/roles/:id' do
    let(:role) { create(:role) }

    it 'updates the role' do
      patch "/api/v1/roles/#{role.uid}.json", params: { role: { name: 'Updated' } }.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
    end
  end

  describe 'DELETE /api/v1/roles/:id' do
    let!(:role_to_delete) { create(:role, name: 'Deletable') }

    it 'deletes the role' do
      delete "/api/v1/roles/#{role_to_delete.uid}.json", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
    end

    it 'returns error for nonexistent role' do
      delete '/api/v1/roles/bad-uid.json', headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['success']).to be false
    end
  end
end

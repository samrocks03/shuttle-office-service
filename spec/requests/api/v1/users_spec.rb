# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Users', type: :request do
  let(:admin) { create(:user) }
  let(:headers) { auth_headers(admin) }

  describe 'GET /api/v1/users' do
    before { create_list(:user, 3) }

    it 'returns paginated users' do
      get '/api/v1/users.json', headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
    end
  end

  describe 'GET /api/v1/users/:id' do
    it 'returns the user' do
      get "/api/v1/users/#{admin.uid}.json", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
    end

    it 'returns 404 for invalid uid' do
      get '/api/v1/users/bad.json', headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /api/v1/users/:id' do
    it 'updates the user' do
      patch "/api/v1/users/#{admin.uid}.json", params: { user: { first_name: 'Updated' } }.to_json, headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'DELETE /api/v1/users/:id' do
    let!(:target_user) { create(:user) }

    it 'destroys the user' do
      delete "/api/v1/users/#{target_user.uid}.json", headers: headers
      expect(response).to have_http_status(:ok)
    end
  end
end

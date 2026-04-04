# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Auth', type: :request do
  let(:company) { create(:company) }
  let(:role) { create(:role, :admin) }

  describe 'POST /api/v1/login' do
    let!(:user) { create(:user, email: 'login@test.com', password: 'password123', company: company, role: role) }

    context 'with valid credentials' do
      it 'returns token and user data' do
        post '/api/v1/login', params: { user: { email: 'login@test.com', password: 'password123' } }.to_json,
                              headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:accepted)
        expect(json_response['success']).to be true
        expect(json_response['data']['token']).to be_present
      end
    end

    context 'with wrong password' do
      it 'returns unauthorized' do
        post '/api/v1/login', params: { user: { email: 'login@test.com', password: 'wrong' } }.to_json,
                              headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['success']).to be false
      end
    end

    context 'with non-existent email' do
      it 'returns unauthorized' do
        post '/api/v1/login', params: { user: { email: 'nobody@test.com', password: 'x' } }.to_json,
                              headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'POST /api/v1/register' do
    context 'with valid params' do
      it 'creates user and returns token' do
        post '/api/v1/register', params: {
          user: {
            first_name: 'John', last_name: 'Doe', phone_number: '1234567890',
            email: 'john@test.com', password: 'password123',
            company_id: company.id, role_id: role.id
          }
        }.to_json, headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:created)
        expect(json_response['success']).to be true
        expect(json_response['data']['token']).to be_present
      end
    end

    context 'with invalid params' do
      it 'returns validation errors' do
        post '/api/v1/register', params: {
          user: { first_name: '', email: 'bad', password: 'x' }
        }.to_json, headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'unauthenticated access' do
    it 'returns 401 without token' do
      get '/api/v1/buses.json'
      expect(response).to have_http_status(:unauthorized)
    end
  end
end

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

    it 'refuses with 422 and a plain message when the user has a reservation with a payment' do
      reservation = create(:reservation, user: target_user, status: 'cancelled', fare_amount_minor: 3500,
                                         currency: 'INR')
      create(:payment, reservation: reservation, status: 'succeeded')

      delete "/api/v1/users/#{target_user.uid}.json", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['errors']['base']).to eq(['This record has payment history and cannot be deleted'])
      expect(User.exists?(target_user.id)).to be(true)
      expect(Payment.count).to eq(1)
    end

    it 'destroys a user who overrode a distance and keeps the override' do
      distance = create(:stop_distance, override_km: 17.0, override_reason: 'shorter road', overridden_by: target_user)

      delete "/api/v1/users/#{target_user.uid}.json", headers: headers

      expect(response).to have_http_status(:ok)
      distance.reload
      expect(distance.overridden_by_id).to be_nil
      expect(distance.override_km).to eq(BigDecimal('17.0'))
    end

    it 'nullifies the override at the database level too' do
      distance = create(:stop_distance, override_km: 17.0, overridden_by: target_user)

      target_user.delete

      expect(distance.reload.overridden_by_id).to be_nil
    end
  end
end

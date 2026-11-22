# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::StopDistances', type: :request do
  let(:admin) { create(:user, role: create(:role, :admin)) }
  let(:employee) { create(:user, role: create(:role, :user_role)) }
  let(:guest) { create(:user, role: create(:role, :guest)) }
  let(:city) { create(:city, distance_provider: 'haversine') }
  let(:pickup) { create(:stop, city: city, name: 'Hinjewadi') }
  let(:office) { create(:stop, :office, city: city, name: 'Magarpatta') }
  let!(:distance) { create(:stop_distance, from_stop: pickup, to_stop: office, computed_km: 18.4) }
  let(:path) { "/api/v1/stop_distances/#{distance.uid}.json" }

  def patch_override(user: admin, **body)
    patch path, params: body.to_json, headers: auth_headers(user)
  end

  describe 'GET /api/v1/stop_distances' do
    let(:other_city) { create(:city) }

    before do
      create(:stop_distance, from_stop: office, to_stop: pickup, computed_km: nil, computed_minutes: nil)
      create(:stop_distance, from_stop: create(:stop, city: other_city),
                             to_stop: create(:stop, :office, city: other_city))
    end

    it 'lists the pairs of one city with the effective km and the unrouted flag' do
      distance.update!(override_km: 20.0, override_reason: 'Bridge closed')

      get '/api/v1/stop_distances.json', params: { city_uid: city.uid }, headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      rows = json_response['data'].map { |row| row['attributes'] }
      expect(rows.size).to eq(2)
      routed = rows.find { |row| row['uid'] == distance.uid }
      expect(routed).to include('computed_km' => 18.4, 'override_km' => 20.0, 'effective_km' => 20.0,
                                'override_reason' => 'Bridge closed', 'unrouted' => false)
      expect(routed['from_stop']).to include('name' => 'Hinjewadi', 'kind' => 'pickup')
      expect(routed['to_stop']).to include('name' => 'Magarpatta', 'kind' => 'office')
      unrouted = rows.find { |row| row['uid'] != distance.uid }
      expect(unrouted).to include('computed_km' => nil, 'effective_km' => nil, 'unrouted' => true)
      expect(json_response['meta']).to include('total_count' => 2)
    end

    it 'needs a known city' do
      get '/api/v1/stop_distances.json', headers: auth_headers(admin)
      expect(response).to have_http_status(:not_found)

      get '/api/v1/stop_distances.json', params: { city_uid: SecureRandom.uuid }, headers: auth_headers(admin)
      expect(response).to have_http_status(:not_found)
    end

    it 'does not run a query per row' do
      distance.update!(override_km: 3, overridden_by: admin)
      headers = auth_headers(admin)
      count_queries = lambda do
        queries = 0
        counter = ->(*, payload) { queries += 1 unless payload[:name] == 'SCHEMA' || payload[:cached] }
        ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
          get '/api/v1/stop_distances.json', params: { city_uid: city.uid }, headers: headers
        end
        queries
      end

      few = count_queries.call
      5.times do
        create(:stop_distance, from_stop: pickup, to_stop: create(:stop, :office, city: city),
                               override_km: 3, overridden_by: admin)
      end

      expect(count_queries.call).to eq(few)
    end

    it 'is admin only' do
      [employee, guest].each do |user|
        get '/api/v1/stop_distances.json', params: { city_uid: city.uid }, headers: auth_headers(user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    it 'requires a token' do
      get '/api/v1/stop_distances.json', params: { city_uid: city.uid }, headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH /api/v1/stop_distances/:uid' do
    it 'sets an override and records who made it' do
      patch_override(override_km: 21.5, override_reason: 'Flyover shortcut')

      expect(response).to have_http_status(:ok)
      attributes = json_response['data']['attributes']
      expect(attributes).to include('override_km' => 21.5, 'effective_km' => 21.5, 'computed_km' => 18.4,
                                    'override_reason' => 'Flyover shortcut', 'overridden_by_name' => admin.first_name + ' ' + admin.last_name)
      distance.reload
      expect(distance.override_km).to eq(21.5)
      expect(distance.override_reason).to eq('Flyover shortcut')
      expect(distance.overridden_by_id).to eq(admin.id)
    end

    it 'clears the override with a null km' do
      distance.update!(override_km: 21.5, override_reason: 'x', overridden_by: admin)

      patch_override(override_km: nil)

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['attributes']).to include('override_km' => nil, 'effective_km' => 18.4,
                                                             'override_reason' => nil, 'overridden_by_name' => nil)
      distance.reload
      expect([distance.override_km, distance.override_reason, distance.overridden_by_id]).to all(be_nil)
      expect(distance.computed_km).to eq(18.4)
    end

    it 'lets an override make an unrouted pair routed' do
      distance.update!(computed_km: nil, computed_minutes: nil)

      patch_override(override_km: 12, override_reason: 'Measured by hand')

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['attributes']).to include('unrouted' => false, 'effective_km' => 12.0)
    end

    it 'forbids an employee and leaves the row unchanged' do
      patch_override(user: employee, override_km: 21.5, override_reason: 'nope')

      expect(response).to have_http_status(:forbidden)
      expect(distance.reload.override_km).to be_nil
    end

    it 'forbids a guest' do
      patch_override(user: guest, override_km: 21.5)

      expect(response).to have_http_status(:forbidden)
      expect(distance.reload.override_km).to be_nil
    end

    it 'returns 404 for an unknown uid' do
      patch "/api/v1/stop_distances/#{SecureRandom.uuid}.json", params: { override_km: 5 }.to_json,
                                                                headers: auth_headers(admin)

      expect(response).to have_http_status(:not_found)
    end

    it 'rejects zero, negative, over-limit and non-numeric kilometres' do
      [0, -3, 500.5, 'abc', ''].each do |bad|
        patch_override(override_km: bad, override_reason: 'bad')

        expect(response).to have_http_status(:unprocessable_entity), "expected 422 for #{bad.inspect}"
        expect(json_response['errors']['base']).not_to be_empty
        expect(distance.reload.override_km).to be_nil
      end
    end

    it 'accepts the largest allowed override' do
      patch_override(override_km: 500, override_reason: 'Intercity')

      expect(response).to have_http_status(:ok)
      expect(distance.reload.override_km).to eq(500)
    end

    it 'rejects a request that does not mention override_km' do
      patch_override(override_reason: 'only a reason')

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects a reason longer than 255 characters' do
      patch_override(override_km: 5, override_reason: 'a' * 256)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(distance.reload.override_km).to be_nil
    end

    it 'survives Distances::ComputeForCity' do
      patch_override(override_km: 21.5, override_reason: 'Flyover shortcut')
      expect(response).to have_http_status(:ok)

      Distances::ComputeForCity.new(city).call

      distance.reload
      expect(distance.override_km).to eq(21.5)
      expect(distance.override_reason).to eq('Flyover shortcut')
      expect(distance.overridden_by_id).to eq(admin.id)
      expect(distance.computed_km).not_to eq(18.4) # recomputed by the provider
      expect(distance.effective_km).to eq(21.5)
    end
  end
end

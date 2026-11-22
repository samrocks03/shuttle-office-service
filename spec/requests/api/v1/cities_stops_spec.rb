# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1 cities and stops', type: :request do
  let(:admin) { create(:user, role: create(:role, :admin)) }
  let(:employee) { create(:user, role: create(:role, :user_role)) }
  let(:guest) { create(:user, role: create(:role, :guest)) }
  let!(:city) { create(:city, name: 'Pune') }
  let!(:pickup) { create(:stop, city: city, name: 'Baner', latitude: 18.559, longitude: 73.7868) }
  let!(:office) { create(:stop, :office, city: city, name: 'Magarpatta') }
  let!(:other_stop) { create(:stop, city: create(:city)) }

  describe 'GET /api/v1/cities' do
    it 'lets an admin and an employee list cities with stop counts' do
      [admin, employee].each do |user|
        get '/api/v1/cities.json', headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        pune = json_response['data'].map { |row| row['attributes'] }.find { |row| row['name'] == 'Pune' }
        expect(pune).to include('uid' => city.uid, 'currency' => 'INR', 'stops_count' => 2)
      end
    end

    it 'forbids a guest' do
      get '/api/v1/cities.json', headers: auth_headers(guest)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/v1/cities/:uid' do
    it 'shows a city by uid' do
      get "/api/v1/cities/#{city.uid}.json", headers: auth_headers(employee)

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['attributes']).to include('uid' => city.uid, 'name' => 'Pune')
    end

    it 'does not accept a numeric id' do
      get "/api/v1/cities/#{city.id}.json", headers: auth_headers(admin)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/v1/cities/:city_uid/stops' do
    it 'lists the stops of that city only, with coordinates' do
      get "/api/v1/cities/#{city.uid}/stops.json", headers: auth_headers(employee)

      expect(response).to have_http_status(:ok)
      rows = json_response['data'].map { |row| row['attributes'] }
      expect(rows.map { |row| row['name'] }).to contain_exactly('Baner', 'Magarpatta')
      expect(rows.find { |row| row['name'] == 'Baner' }).to include('kind' => 'pickup', 'latitude' => 18.559,
                                                                    'longitude' => 73.7868, 'active' => true)
    end

    it 'forbids a guest' do
      get "/api/v1/cities/#{city.uid}/stops.json", headers: auth_headers(guest)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'stop writes' do
    let(:stops_path) { "/api/v1/cities/#{city.uid}/stops.json" }
    let(:stop_params) { { stop: { name: 'Kharadi', kind: 'pickup', latitude: 18.55, longitude: 73.94 } } }

    it 'lets an admin create a stop' do
      expect { post stops_path, params: stop_params.to_json, headers: auth_headers(admin) }
        .to change { city.stops.count }.by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['data']['attributes']).to include('name' => 'Kharadi', 'kind' => 'pickup')
    end

    it 'rejects an invalid stop' do
      post stops_path, params: { stop: { name: '', kind: 'moon' } }.to_json, headers: auth_headers(admin)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'forbids an employee from creating, updating or deleting' do
      headers = auth_headers(employee)

      expect { post stops_path, params: stop_params.to_json, headers: headers }.not_to(change { Stop.count })
      expect(response).to have_http_status(:forbidden)

      patch "/api/v1/cities/#{city.uid}/stops/#{pickup.uid}.json", params: { stop: { name: 'X' } }.to_json,
                                                                    headers: headers
      expect(response).to have_http_status(:forbidden)
      expect(pickup.reload.name).to eq('Baner')

      expect { delete "/api/v1/cities/#{city.uid}/stops/#{pickup.uid}.json", headers: headers }
        .not_to(change { Stop.count })
      expect(response).to have_http_status(:forbidden)
    end

    it 'lets an admin update a stop' do
      patch "/api/v1/cities/#{city.uid}/stops/#{pickup.uid}.json", params: { stop: { name: 'Baner Road' } }.to_json,
                                                                    headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(pickup.reload.name).to eq('Baner Road')
    end

    it 'does not reach a stop through another city' do
      patch "/api/v1/cities/#{city.uid}/stops/#{other_stop.uid}.json", params: { stop: { name: 'X' } }.to_json,
                                                                        headers: auth_headers(admin)

      expect(response).to have_http_status(:not_found)
    end

    it 'lets an admin delete an unused stop together with its distance rows' do
      create(:stop_distance, from_stop: pickup, to_stop: office)

      expect { delete "/api/v1/cities/#{city.uid}/stops/#{pickup.uid}.json", headers: auth_headers(admin) }
        .to change { Stop.count }.by(-1).and change { StopDistance.count }.by(-1)

      expect(response).to have_http_status(:ok)
    end

    it 'refuses to delete a stop a schedule uses' do
      create(:schedule, from_stop: pickup, to_stop: office)

      expect { delete "/api/v1/cities/#{city.uid}/stops/#{pickup.uid}.json", headers: auth_headers(admin) }
        .not_to(change { Stop.count })

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end

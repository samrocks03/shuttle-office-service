# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::FareTables', type: :request do
  let(:admin) { create(:user, role: create(:role, :admin)) }
  let(:employee) { create(:user, role: create(:role, :user_role)) }
  let(:city) { create(:city) }
  let!(:non_ac) { create(:fare_table, :best_non_ac, city: city) }
  let!(:ac) { create(:fare_table, :best_ac, city: city) }
  let!(:other) { create(:fare_table, :best_ac, city: create(:city)) }

  describe 'GET /api/v1/fare_tables' do
    it 'lists the tables of a city with their slabs in km order' do
      get '/api/v1/fare_tables.json', params: { city_uid: city.uid }, headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      tables = json_response['data'].map { |row| row['attributes'] }
      expect(tables.map { |table| table['uid'] }).to contain_exactly(non_ac.uid, ac.uid)
      first = tables.find { |table| table['uid'] == non_ac.uid }
      expect(first).to include('service_class' => 'non_ac', 'currency' => 'INR', 'policy' => 'slab',
                               'step_km' => 5.0, 'step_amount_minor' => 500, 'active' => true)
      expect(first['slabs'].first).to eq('up_to_km' => 5.0, 'amount_minor' => 1000)
      expect(first['slabs'].map { |slab| slab['up_to_km'] }).to eq(first['slabs'].map { |slab| slab['up_to_km'] }.sort)
    end

    it 'needs a known city' do
      get '/api/v1/fare_tables.json', headers: auth_headers(admin)
      expect(response).to have_http_status(:not_found)
    end

    it 'forbids an employee' do
      get '/api/v1/fare_tables.json', params: { city_uid: city.uid }, headers: auth_headers(employee)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/v1/fare_tables/:uid' do
    it 'shows one table with slabs' do
      get "/api/v1/fare_tables/#{ac.uid}.json", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['attributes']['slabs'].size).to eq(10)
    end

    it 'forbids an employee' do
      get "/api/v1/fare_tables/#{ac.uid}.json", headers: auth_headers(employee)
      expect(response).to have_http_status(:forbidden)
    end
  end
end

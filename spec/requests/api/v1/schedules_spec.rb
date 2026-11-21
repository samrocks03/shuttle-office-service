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

    it 'does not mark a schedule as booked by an expired or cancelled reservation' do
      expired_on = create(:schedule, bus: bus)
      active_on = create(:schedule, bus: bus)
      create(:reservation, user: user, schedule: expired_on, status: 'expired')
      create(:reservation, user: user, schedule: active_on, status: 'pending_payment')

      get '/api/v1/schedules.json', params: { per_page: 100 }, headers: headers

      booked = json_response['data'].to_h { |row| [row['attributes']['uid'], row['attributes']['booked_by_current_user']] }
      expect(booked[expired_on.uid]).to be false
      expect(booked[active_on.uid]).to be true
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

  describe 'fare on schedules' do
    let(:city) { create(:city) }
    let(:company) { create(:company, city: city) }
    let(:ac_bus) { create(:bus, company: company, service_class: 'ac') }
    let(:from_stop) { create(:stop, city: city) }
    let(:to_stop) { create(:stop, :office, city: city) }
    let!(:priced) do
      create(:schedule, bus: ac_bus, date: Date.new(2026, 12, 15), from_stop: from_stop, to_stop: to_stop)
    end

    def listed(schedule)
      json_response['data'].find { |row| row['attributes']['uid'] == schedule.uid }['attributes']
    end

    before do
      create(:stop_distance, from_stop: from_stop, to_stop: to_stop, computed_km: 18.4)
      create(:fare_table, :best_ac, city: city, effective_from: Date.new(2026, 12, 1))
    end

    it 'includes the fare in the schedule list' do
      get '/api/v1/schedules.json', params: { per_page: 100 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(listed(priced)['fare']).to eq(
        'amount_minor' => 3500, 'currency' => 'INR', 'distance_km' => 18.4, 'slab_label' => 'up to 20 km'
      )
      expect(listed(priced)['fare_unavailable_reason']).to be_nil
      expect(listed(priced)['bus_service_class']).to eq('ac')
    end

    it 'includes the fare when showing one schedule' do
      get "/api/v1/schedules/#{priced.uid}.json", headers: headers

      expect(json_response['data']['attributes']['fare']['amount_minor']).to eq(3500)
      expect(json_response['data']['attributes']['bus_service_class']).to eq('ac')
    end

    it 'reports payments_enabled false for a company whose city has payments off' do
      get '/api/v1/schedules.json', params: { per_page: 100 }, headers: headers

      expect(listed(priced)['payments_enabled']).to be(false)
    end

    it 'reports payments_enabled true for a company whose city has payments on' do
      city.update!(payments_enabled: true)

      get "/api/v1/schedules/#{priced.uid}.json", headers: headers

      expect(json_response['data']['attributes']['payments_enabled']).to be(true)
    end

    it 'reports payments_enabled false for a company with no city' do
      free = create(:schedule, bus: create(:bus, company: create(:company, city: nil)))

      get "/api/v1/schedules/#{free.uid}.json", headers: headers

      expect(json_response['data']['attributes']['payments_enabled']).to be(false)
    end

    it 'lists a schedule without stops with a null fare and a reason' do
      unpriced = create(:schedule, bus: ac_bus, date: Date.new(2026, 12, 16))

      get '/api/v1/schedules.json', params: { per_page: 100 }, headers: headers

      expect(listed(unpriced)['fare']).to be_nil
      expect(listed(unpriced)['fare_unavailable_reason']).to eq('no_stops')
    end

    it 'loads the bus, company, city and stops with a fixed number of queries however many schedules there are' do
      count_queries = lambda do
        queries = []
        callback = lambda do |_name, _start, _finish, _id, payload|
          queries << payload[:sql] if payload[:sql] =~ /FROM "(cities|stops|buses|companies)"/
        end
        ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
          get '/api/v1/schedules.json', params: { per_page: 100 }, headers: headers
        end
        queries.size
      end

      headers # build the user outside the counted requests
      few = count_queries.call
      create_list(:schedule, 4, bus: ac_bus, from_stop: from_stop, to_stop: to_stop)

      expect(json_response['data'].size).to eq(1)
      expect(count_queries.call).to eq(few)
      expect(json_response['data'].size).to eq(5)
    end
  end

  describe 'stops on write' do
    let(:city) { create(:city) }
    let(:from_stop) { create(:stop, city: city) }
    let(:to_stop) { create(:stop, :office, city: city) }
    let(:base) do
      { start_point: 'Office', arrival_time: '10:00', departure_time: '09:00',
        date: (Date.today + 30).to_s, bus_id: bus.id }
    end

    it 'creates a schedule with stops given by uid' do
      post '/api/v1/schedules.json',
           params: { schedule: base.merge(from_stop_uid: from_stop.uid, to_stop_uid: to_stop.uid) }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(Schedule.find_by!(uid: json_response['data']['attributes']['uid']))
        .to have_attributes(from_stop_id: from_stop.id, to_stop_id: to_stop.id)
    end

    it 'rejects an unknown stop uid with 422 and creates nothing' do
      expect do
        post '/api/v1/schedules.json',
             params: { schedule: base.merge(from_stop_uid: SecureRandom.uuid, to_stop_uid: to_stop.uid) }.to_json,
             headers: headers
      end.not_to change(Schedule, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects a malformed stop uid with 422' do
      post '/api/v1/schedules.json',
           params: { schedule: base.merge(from_stop_uid: 'not-a-uuid') }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'sets stops on update and rejects an unknown uid' do
      schedule = create(:schedule, bus: bus)

      patch "/api/v1/schedules/#{schedule.uid}.json",
            params: { schedule: { from_stop_uid: from_stop.uid, to_stop_uid: to_stop.uid } }.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(schedule.reload).to have_attributes(from_stop_id: from_stop.id, to_stop_id: to_stop.id)

      patch "/api/v1/schedules/#{schedule.uid}.json",
            params: { schedule: { to_stop_uid: SecureRandom.uuid } }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(schedule.reload.to_stop_id).to eq(to_stop.id)
    end

    it 'leaves the stops alone on update when no stop uid is sent' do
      schedule = create(:schedule, bus: bus, from_stop: from_stop, to_stop: to_stop)

      patch "/api/v1/schedules/#{schedule.uid}.json",
            params: { schedule: { start_point: 'Elsewhere' } }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(schedule.reload).to have_attributes(from_stop_id: from_stop.id, to_stop_id: to_stop.id)
    end
  end
end

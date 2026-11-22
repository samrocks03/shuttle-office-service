# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Reservations access control', type: :request do
  let(:employee) { create(:user, role: create(:role, :user_role)) }
  let(:other_employee) { create(:user, role: create(:role, :user_role)) }
  let(:admin) { create(:user, role: create(:role, :admin)) }
  let(:guest) { create(:user, role: create(:role, :guest)) }
  let(:schedule) { create(:schedule, available_seats: 40) }

  describe 'GET /api/v1/reservations' do
    it 'employee sees only own reservations in index' do
      mine = create(:reservation, user: employee, schedule: schedule)
      create(:reservation, user: other_employee, schedule: schedule)

      get '/api/v1/reservations.json', params: { per_page: 100 }, headers: auth_headers(employee)

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['attributes']['uid'] }).to eq([mine.uid])
      expect(json_response['meta']['total_count']).to eq(1)
    end
  end

  describe 'GET /api/v1/reservations/:id' do
    let!(:reservation) { create(:reservation, user: other_employee, schedule: schedule) }

    it "show of another user's reservation returns 404" do
      get "/api/v1/reservations/#{reservation.uid}.json", headers: auth_headers(employee)

      expect(response).to have_http_status(:not_found)
    end

    it 'admin can show any reservation' do
      get "/api/v1/reservations/#{reservation.uid}.json", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'DELETE /api/v1/reservations/:id' do
    let!(:reservation) do
      create(:reservation, user: other_employee, schedule: schedule).tap { schedule.decrement_available_seat! }
    end

    it "destroy of another user's reservation returns 404 and keeps it" do
      expect do
        delete "/api/v1/reservations/#{reservation.uid}.json", headers: auth_headers(employee)
      end.not_to(change { schedule.reload.available_seats })

      expect(response).to have_http_status(:not_found)
      expect(Reservation.exists?(reservation.id)).to be true
    end

    it 'admin can destroy any reservation' do
      delete "/api/v1/reservations/#{reservation.uid}.json", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(Reservation.exists?(reservation.id)).to be false
    end
  end

  describe 'POST /api/v1/reservations' do
    it 'create ignores user_id from an employee' do
      post '/api/v1/reservations.json',
           params: { reservation: { schedule_id: schedule.id, user_id: other_employee.id } }.to_json,
           headers: auth_headers(employee)

      expect(response).to have_http_status(:created)
      expect(Reservation.last.user_id).to eq(employee.id)
    end

    it 'guest cannot create' do
      guest_headers = auth_headers(guest)

      expect do
        post '/api/v1/reservations.json',
             params: { reservation: { schedule_id: schedule.id } }.to_json,
             headers: guest_headers
      end.not_to(change(Reservation, :count))

      expect(response).to have_http_status(:forbidden)
    end
  end
end

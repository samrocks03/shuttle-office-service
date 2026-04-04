# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Reservations API', type: :request do
  let(:auth_user) { create(:user) }
  let(:Authorization) { "Bearer #{JWT.encode({ user_id: auth_user.id, user_uid: auth_user.uid }, Rails.application.credentials[:secret_key_base])}" }
  let(:test_schedule) { create(:schedule, available_seats: 40) }

  path '/api/v1/reservations' do
    get 'List reservations' do
      tags 'Reservations'
      produces 'application/json'
      security [bearer_auth: []]
      parameter name: :search, in: :query, type: :string, required: false
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'reservations listed' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :array,
                   items: { type: :object, properties: { id: { type: :string }, type: { type: :string }, attributes: { type: :object } } }
                 },
                 meta: {
                   type: :object,
                   properties: {
                     current_page: { type: :integer },
                     per_page: { type: :integer },
                     total_count: { type: :integer },
                     total_pages: { type: :integer }
                   }
                 },
                 message: { type: :string }
               },
               required: %w[success data]

        run_test!
      end
    end

    post 'Create a reservation' do
      tags 'Reservations'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :reservation, in: :body, schema: {
        type: :object,
        properties: {
          reservation: {
            type: :object,
            properties: {
              schedule_id: { type: :integer },
              user_id: { type: :integer }
            },
            required: %w[schedule_id]
          }
        }
      }

      response '201', 'reservation created' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: { id: { type: :string }, type: { type: :string }, attributes: { type: :object } }
                 },
                 message: { type: :string }
               },
               required: %w[success data]

        let(:reservation) { { reservation: { schedule_id: test_schedule.id, user_id: auth_user.id } } }
        run_test!
      end

      response '422', 'no seats available' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 errors: {
                   type: :object,
                   properties: { base: { type: :array, items: { type: :string } } }
                 },
                 error_key: { type: :string }
               },
               required: %w[success errors]

        let(:reservation) do
          test_schedule.update!(available_seats: 0)
          { reservation: { schedule_id: test_schedule.id, user_id: auth_user.id } }
        end
        run_test!
      end
    end
  end

  path '/api/v1/reservations/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Reservation UID'

    get 'Show a reservation' do
      tags 'Reservations'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'reservation found' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: { id: { type: :string }, type: { type: :string }, attributes: { type: :object } }
                 },
                 message: { type: :string }
               },
               required: %w[success data]

        let(:id) { create(:reservation, user: auth_user, schedule: test_schedule).uid }
        run_test!
      end

      response '404', 'not found' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 errors: {
                   type: :object,
                   properties: { base: { type: :array, items: { type: :string } } }
                 },
                 error_key: { type: :string }
               },
               required: %w[success errors]

        let(:id) { 'bad' }
        run_test!
      end
    end

    delete 'Delete a reservation' do
      tags 'Reservations'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'reservation deleted' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 message: { type: :string }
               },
               required: %w[success message]

        let(:id) { create(:reservation, user: auth_user, schedule: test_schedule).uid }
        run_test!
      end
    end
  end
end

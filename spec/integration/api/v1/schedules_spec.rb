# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Schedules API', type: :request do
  let(:auth_user) { create(:user) }
  let(:Authorization) { "Bearer #{JWT.encode({ user_id: auth_user.id, user_uid: auth_user.uid }, Rails.application.credentials[:secret_key_base])}" }
  let(:test_bus) { create(:bus) }

  path '/api/v1/schedules' do
    get 'List schedules' do
      tags 'Schedules'
      produces 'application/json'
      security [bearer_auth: []]
      parameter name: :search, in: :query, type: :string, required: false
      parameter name: :bus_id, in: :query, type: :integer, required: false, description: 'Filter by bus'
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :sort_by, in: :query, type: :string, required: false
      parameter name: :sort_order, in: :query, type: :string, required: false, enum: %w[asc desc]

      response '200', 'schedules listed' do
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

        before { create(:schedule, bus: test_bus) }
        run_test!
      end
    end

    post 'Create a schedule' do
      tags 'Schedules'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :schedule, in: :body, schema: {
        type: :object,
        properties: {
          schedule: {
            type: :object,
            properties: {
              start_point: { type: :string },
              arrival_time: { type: :string, example: '10:00' },
              departure_time: { type: :string, example: '09:00' },
              date: { type: :string, format: :date },
              bus_id: { type: :integer }
            },
            required: %w[start_point arrival_time departure_time date bus_id]
          }
        }
      }

      response '201', 'schedule created' do
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

        let(:schedule) do
          { schedule: { start_point: 'Office', arrival_time: '10:00', departure_time: '09:00',
                        date: (Date.today + 30).to_s, bus_id: test_bus.id } }
        end
        run_test!
      end

      response '422', 'past date rejected' do
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

        let(:schedule) do
          { schedule: { start_point: 'Office', arrival_time: '10:00', departure_time: '09:00',
                        date: '2020-01-01', bus_id: test_bus.id } }
        end
        run_test!
      end
    end
  end

  path '/api/v1/schedules/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Schedule UID'

    get 'Show a schedule' do
      tags 'Schedules'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'schedule found' do
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

        let(:id) { create(:schedule, bus: test_bus).uid }
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

    patch 'Update a schedule' do
      tags 'Schedules'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :schedule, in: :body, schema: {
        type: :object,
        properties: {
          schedule: {
            type: :object,
            properties: { start_point: { type: :string }, date: { type: :string } }
          }
        }
      }

      response '200', 'schedule updated' do
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

        let(:id) { create(:schedule, bus: test_bus).uid }
        let(:schedule) { { schedule: { start_point: 'New Location' } } }
        run_test!
      end
    end

    delete 'Delete a schedule' do
      tags 'Schedules'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'schedule deleted' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 message: { type: :string }
               },
               required: %w[success message]

        let(:id) { create(:schedule, bus: test_bus).uid }
        run_test!
      end
    end
  end
end

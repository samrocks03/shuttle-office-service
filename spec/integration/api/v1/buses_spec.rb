# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Buses API', type: :request do
  let(:auth_user) { create(:user) }
  let(:Authorization) { "Bearer #{JWT.encode({ user_id: auth_user.id, user_uid: auth_user.uid }, Rails.application.credentials[:secret_key_base])}" }

  path '/api/v1/buses' do
    get 'List buses' do
      tags 'Buses'
      produces 'application/json'
      security [bearer_auth: []]
      parameter name: :search, in: :query, type: :string, required: false
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'buses listed' do
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

        before { create_list(:bus, 2) }
        run_test!
      end
    end

    post 'Create a bus' do
      tags 'Buses'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :bus, in: :body, schema: {
        type: :object,
        properties: {
          bus: {
            type: :object,
            properties: {
              number: { type: :string },
              capacity: { type: :integer },
              model: { type: :string },
              company_id: { type: :integer }
            },
            required: %w[number capacity model company_id]
          }
        }
      }

      response '201', 'bus created' do
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

        let(:bus) { { bus: { number: 'SW-001', capacity: 40, model: 'Volvo', company_id: create(:company).id } } }
        run_test!
      end

      response '422', 'invalid params' do
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

        let(:bus) { { bus: { number: '', capacity: nil } } }
        run_test!
      end
    end
  end

  path '/api/v1/buses/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Bus UID'

    get 'Show a bus' do
      tags 'Buses'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'bus found' do
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

        let(:id) { create(:bus).uid }
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

    patch 'Update a bus' do
      tags 'Buses'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :bus, in: :body, schema: {
        type: :object,
        properties: {
          bus: { type: :object, properties: { capacity: { type: :integer }, model: { type: :string } } }
        }
      }

      response '200', 'bus updated' do
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

        let(:id) { create(:bus).uid }
        let(:bus) { { bus: { capacity: 50 } } }
        run_test!
      end
    end

    delete 'Delete a bus' do
      tags 'Buses'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'bus deleted' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 message: { type: :string }
               },
               required: %w[success message]

        let(:id) { create(:bus).uid }
        run_test!
      end
    end
  end
end

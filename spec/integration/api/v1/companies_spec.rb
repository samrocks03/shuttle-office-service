# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Companies API', type: :request do
  let(:auth_user) { create(:user) }
  let(:Authorization) { "Bearer #{JWT.encode({ user_id: auth_user.id, user_uid: auth_user.uid }, Rails.application.credentials[:secret_key_base])}" }

  path '/api/v1/companies' do
    get 'List companies' do
      tags 'Companies'
      produces 'application/json'
      security [bearer_auth: []]
      parameter name: :search, in: :query, type: :string, required: false
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :sort_by, in: :query, type: :string, required: false
      parameter name: :sort_order, in: :query, type: :string, required: false, enum: %w[asc desc]

      response '200', 'companies listed' do
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

        before { create_list(:company, 2) }
        run_test!
      end
    end

    post 'Create a company' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :company, in: :body, schema: {
        type: :object,
        properties: {
          company: {
            type: :object,
            properties: {
              name: { type: :string },
              location: { type: :string }
            },
            required: %w[name location]
          }
        }
      }

      response '201', 'company created' do
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

        let(:company) { { company: { name: 'SwaggerCo', location: 'Mumbai' } } }
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

        let(:company) { { company: { name: '', location: '' } } }
        run_test!
      end
    end
  end

  path '/api/v1/companies/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Company UID'

    get 'Show a company' do
      tags 'Companies'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'company found' do
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

        let(:id) { create(:company).uid }
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

    patch 'Update a company' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :company, in: :body, schema: {
        type: :object,
        properties: {
          company: {
            type: :object,
            properties: { name: { type: :string }, location: { type: :string } }
          }
        }
      }

      response '200', 'company updated' do
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

        let(:id) { create(:company).uid }
        let(:company) { { company: { name: 'Updated' } } }
        run_test!
      end
    end

    delete 'Delete a company' do
      tags 'Companies'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'company deleted' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 message: { type: :string }
               },
               required: %w[success message]

        let(:id) { create(:company).uid }
        run_test!
      end
    end
  end
end

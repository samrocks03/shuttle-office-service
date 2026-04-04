# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Roles API', type: :request do
  let(:auth_user) { create(:user) }
  let(:Authorization) { "Bearer #{JWT.encode({ user_id: auth_user.id, user_uid: auth_user.uid }, Rails.application.credentials[:secret_key_base])}" }

  path '/api/v1/roles' do
    get 'List roles' do
      tags 'Roles'
      produces 'application/json'
      security [bearer_auth: []]
      parameter name: :search, in: :query, type: :string, required: false, description: 'Search by name'
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :sort_by, in: :query, type: :string, required: false
      parameter name: :sort_order, in: :query, type: :string, required: false, enum: %w[asc desc]

      response '200', 'roles listed' do
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

        before { create_list(:role, 2) }
        run_test!
      end

      # Note: GET /roles index is an open route (no auth required) for dropdown population during registration
    end

    post 'Create a role' do
      tags 'Roles'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :role, in: :body, schema: {
        type: :object,
        properties: {
          role: {
            type: :object,
            properties: {
              name: { type: :string },
              role_type: { type: :string, enum: %w[admin user guest] }
            },
            required: %w[name role_type]
          }
        }
      }

      response '201', 'role created' do
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

        let(:role) { { role: { name: 'Manager', role_type: 'user' } } }
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

        let(:role) { { role: { name: '', role_type: '' } } }
        run_test!
      end
    end
  end

  path '/api/v1/roles/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Role UID'

    get 'Show a role' do
      tags 'Roles'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'role found' do
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

        let(:id) { create(:role).uid }
        run_test!
      end

      response '404', 'role not found' do
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

        let(:id) { 'nonexistent' }
        run_test!
      end
    end

    patch 'Update a role' do
      tags 'Roles'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :role, in: :body, schema: {
        type: :object,
        properties: {
          role: {
            type: :object,
            properties: {
              name: { type: :string },
              role_type: { type: :string }
            }
          }
        }
      }

      response '200', 'role updated' do
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

        let(:id) { create(:role).uid }
        let(:role) { { role: { name: 'Updated Role' } } }
        run_test!
      end
    end

    delete 'Delete a role' do
      tags 'Roles'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'role deleted' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 message: { type: :string }
               },
               required: %w[success message]

        let(:id) { create(:role).uid }
        run_test!
      end
    end
  end
end

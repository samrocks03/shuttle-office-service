# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Users API', type: :request do
  let(:auth_user) { create(:user) }
  let(:Authorization) { "Bearer #{JWT.encode({ user_id: auth_user.id, user_uid: auth_user.uid }, Rails.application.credentials[:secret_key_base])}" }

  path '/api/v1/users' do
    get 'List users' do
      tags 'Users'
      produces 'application/json'
      security [bearer_auth: []]
      parameter name: :search, in: :query, type: :string, required: false
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'users listed' do
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
  end

  path '/api/v1/users/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'User UID'

    get 'Show a user' do
      tags 'Users'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'user found' do
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

        let(:id) { auth_user.uid }
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

    patch 'Update a user' do
      tags 'Users'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              first_name: { type: :string },
              last_name: { type: :string },
              phone_number: { type: :string },
              email: { type: :string }
            }
          }
        }
      }

      response '200', 'user updated' do
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

        let(:id) { auth_user.uid }
        let(:user) { { user: { first_name: 'Updated' } } }
        run_test!
      end
    end

    delete 'Delete a user' do
      tags 'Users'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'user deleted' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 message: { type: :string }
               },
               required: %w[success message]

        let(:id) { create(:user).uid }
        run_test!
      end
    end
  end
end

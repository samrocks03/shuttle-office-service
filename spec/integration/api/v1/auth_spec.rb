# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Auth API', type: :request do
  let(:company) { create(:company) }
  let(:role) { create(:role, :admin) }

  path '/api/v1/login' do
    post 'Login' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, example: 'admin@test.com' },
              password: { type: :string, example: 'password123' }
            },
            required: %w[email password]
          }
        }
      }

      response '202', 'login successful' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: {
                     user: { type: :object },
                     token: { type: :string }
                   }
                 },
                 message: { type: :string }
               },
               required: %w[success data]

        let!(:existing_user) { create(:user, email: 'admin@test.com', password: 'password123', company: company, role: role) }
        let(:user) { { user: { email: 'admin@test.com', password: 'password123' } } }
        run_test!
      end

      response '401', 'invalid credentials' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 errors: {
                   type: :object,
                   properties: { base: { type: :array, items: { type: :string } } }
                 }
               },
               required: %w[success errors]

        let!(:existing_user) { create(:user, email: 'admin@test.com', password: 'password123', company: company, role: role) }
        let(:user) { { user: { email: 'admin@test.com', password: 'wrong' } } }
        run_test!
      end
    end
  end

  path '/api/v1/register' do
    post 'Register' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              first_name: { type: :string },
              last_name: { type: :string },
              phone_number: { type: :string },
              email: { type: :string },
              password: { type: :string },
              company_id: { type: :integer },
              role_id: { type: :integer }
            },
            required: %w[first_name last_name phone_number email password company_id]
          }
        }
      }

      response '201', 'user registered' do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: {
                     user: { type: :object },
                     token: { type: :string }
                   }
                 },
                 message: { type: :string }
               },
               required: %w[success data]

        let(:user) do
          { user: { first_name: 'John', last_name: 'Doe', phone_number: '5551234567',
                     email: 'new@test.com', password: 'password123',
                     company_id: company.id, role_id: role.id } }
        end
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

        let(:user) { { user: { first_name: '', email: '' } } }
        run_test!
      end
    end
  end
end

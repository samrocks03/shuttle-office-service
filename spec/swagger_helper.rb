# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  config.openapi_root = Rails.root.join('swagger').to_s

  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Shuttle Office Service API',
        version: 'v1',
        description: 'API for managing office shuttle bus bookings'
      },
      paths: {},
      servers: [
        { url: 'http://localhost:3000', description: 'Development server' }
      ],
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: :JWT
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end

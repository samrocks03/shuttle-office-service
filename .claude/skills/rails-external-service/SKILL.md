---
name: rails-external-service
description: "Write external HTTP service calls following project conventions: ExternalService::HttpRequest wrapper class using HTTParty, token-based authentication, ENV-driven base URLs, and standardized response handling. Use this skill whenever making API calls to external services, integrating with third-party APIs, or working in app/services/external_service/. Triggers on: 'external API', 'HTTP request', 'API call', 'third party', 'HTTParty', 'external service', 'integration', 'call_http_request', or any external service work."
---

# Rails External Service Patterns

All external HTTP calls in this project go through the `ExternalService::HttpRequest` wrapper. This centralizes HTTP logic, token management, and response handling in one place rather than scattering HTTParty calls across services.

## Location

```
app/services/external_service/
  http_request.rb
  rsense_user.rb       # Service-specific wrappers
```

## The HttpRequest Wrapper

The core pattern wraps HTTParty with consistent token auth, URL assembly, and error handling:

```ruby
# frozen_string_literal: true

module ExternalService
  class HttpRequest
    attr_reader :base_url, :action, :resource_url, :params_or_data, :token

    def initialize(base_url, action, resource_url, params_or_data, token:)
      @base_url = base_url
      @action = action
      @resource_url = resource_url
      @params_or_data = params_or_data
      @token = token
    end

    def call
      url = "#{base_url}#{resource_url}"
      headers = {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{token}"
      }

      response = case action.downcase
                 when 'get'
                   HTTParty.get(url, query: params_or_data, headers: headers)
                 when 'post'
                   HTTParty.post(url, body: params_or_data.to_json, headers: headers)
                 when 'put'
                   HTTParty.put(url, body: params_or_data.to_json, headers: headers)
                 when 'patch'
                   HTTParty.patch(url, body: params_or_data.to_json, headers: headers)
                 when 'delete'
                   HTTParty.delete(url, headers: headers)
                 end

      JSON.parse(response.body)
    rescue StandardError => e
      { 'success' => false, 'errors' => { base: [e.message] } }
    end
  end
end
```

## Using HttpRequest from Services

Services call external APIs through the Base class helper `call_http_request`:

```ruby
def fetch_external_data
  url = ENV.fetch('EXTERNAL_SERVICE_URL', nil)
  resource_url = '/api/v1/widgets'
  token = ENV.fetch('EXTERNAL_SERVICE_TOKEN')
  params = { org_uid: current_user[:org_uid] }

  response = call_http_request(url, 'get', resource_url, params, token)

  return true if response['success']

  add_error('widget.external_fetch.failure', message: response.dig('errors', :base)&.join(', '))
  false
end
```

The Base class provides `call_http_request` as a convenience wrapper:

```ruby
# In Base class
def call_http_request(url, action, resource_url, params_or_data, token)
  ExternalService::HttpRequest.new(url, action, resource_url, params_or_data, token:).call
end
```

## Service-Specific Wrappers

For frequently used external services, create a dedicated wrapper class:

```ruby
# frozen_string_literal: true

module ExternalService
  class RsenseUser
    attr_reader :token

    BASE_URL = ENV.fetch('RSENSE_USER_BASE_URL', nil)

    def initialize(token)
      @token = token
    end

    def fetch_user(user_uid)
      HttpRequest.new(BASE_URL, 'get', "/api/v1/users/#{user_uid}", {}, token:).call
    end

    def update_user(user_uid, params)
      HttpRequest.new(BASE_URL, 'put', "/api/v1/users/#{user_uid}", params, token:).call
    end

    def search_users(query_params)
      HttpRequest.new(BASE_URL, 'get', '/api/v1/users/search', query_params, token:).call
    end
  end
end
```

## Using in Background Jobs

External calls in jobs follow the same pattern with explicit error logging:

```ruby
def perform(org_uid)
  url = ENV.fetch('ACCESS_RIGHTS_BASE_URL', nil)
  resource_url = '/access_rights/org_access_rights'
  token = ENV.fetch('ACCESS_RIGHTS_SECRET_KEY')

  response = ExternalService::HttpRequest.new(url, 'get', resource_url, {}, token:).call

  return true if response['success']

  Sidekiq.logger.error(response['errors'][:base])
  retry_job if executions <= 3
end
```

## Environment Variables

All external service URLs and tokens come from ENV, never hardcoded:

```ruby
url = ENV.fetch('SERVICE_NAME_BASE_URL', nil)    # Base URL
token = ENV.fetch('SERVICE_NAME_SECRET_KEY')      # Auth token
```

Use `ENV.fetch` with a fallback of `nil` for optional URLs, and without fallback for required tokens (so it raises on missing config).

## Encrypted Tokens

For service-to-service auth with encrypted tokens, the Base class provides:

```ruby
def create_encrypted_token
  secret_key = { secret_key: ENV.fetch('RSENSE_ORG_SECRET_KEY', nil) }
  encryption_key = ENV.fetch('RSENSE_ORG_ENCRIPTION_KEY', nil)
  encryptor = ActiveSupport::MessageEncryptor.new(encryption_key)
  encryptor.encrypt_and_sign(secret_key)
rescue ArgumentError => e
  add_error(EXCEPTION_KEY, message: "Secret encryption #{e.message}")
end
```

## Checklist Before Writing External Service Calls

1. Is the call going through `ExternalService::HttpRequest`?
2. Are URLs and tokens from `ENV.fetch`?
3. Is the response checked for `['success']` before processing?
4. Is failure handled with `add_error` (in services) or `Sidekiq.logger.error` (in jobs)?
5. Is error rescue in place for network failures?
6. For frequently used services, is there a dedicated wrapper class?

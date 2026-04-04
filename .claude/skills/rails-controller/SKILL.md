---
name: rails-controller
description: "Write Rails API controllers following project conventions: ActionController::API inheritance, api/v1 namespacing, delegation to service objects, standardized JSON responses with success/failure format, before_action authentication, and proper HTTP status codes. Use this skill whenever creating or modifying controllers, adding actions, or working on API endpoints. Triggers on: 'create controller', 'add action', 'add endpoint', 'API endpoint', 'controller action', 'render json', or any work in app/controllers/."
---

# Rails API Controller Patterns

Controllers in this project are thin API endpoints. They authenticate, authorize, delegate to a service, and render the response. Business logic never lives in controllers.

## Architecture

- **Base**: All controllers inherit from `ApplicationController < ActionController::API`
- **Namespace**: All API controllers live under `Api::V1::`
- **Location**: `app/controllers/api/v1/<resource>_controller.rb`
- **Auth**: JWT + application token authentication via `before_action :authenticate`
- **Authorization**: Role-based via `before_action :authorize_action`
- **Locale**: Multi-language via `around_action :switch_locale`

## ApplicationController (Already Exists)

The base controller provides:
- `authenticate` — tries user JWT, falls back to application token, returns 401
- `authorize_action` — checks ACCESS_RIGHTS_MAPPING, returns 403
- `switch_locale` — sets I18n locale from user preference
- `@current_user` — set after successful auth
- `@decode` — decoded JWT payload
- PaperTrail whodunnit tracking

## Controller Skeleton

```ruby
# frozen_string_literal: true

module Api
  module V1
    class WidgetsController < ApplicationController
      def index
        result = WidgetService::Index.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
      end

      def show
        result = WidgetService::Show.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :not_found
      end

      def create
        result = WidgetService::Create.new(widget_params, current_user_params).call
        render json: result.to_h, status: result.success ? :created : :unprocessable_entity
      end

      def update
        result = WidgetService::Update.new(widget_params.merge(id: params[:id]), current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
      end

      def destroy
        result = WidgetService::Destroy.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
      end

      private

      def widget_params
        params.require(:widget).permit(:name, :code, :status, :description, tags: [])
      end

      def current_user_params
        { org_uid: @decode['org_uid'], user_uid: @current_user&.uid }
      end
    end
  end
end
```

## The Controller Pattern, Step by Step

### 1. Instantiate the service

Every action creates a service instance, passing params and current user context:

```ruby
result = WidgetService::Create.new(widget_params, current_user_params).call
```

### 2. Render the response

The service returns an `OpenStruct` with `success: true/false`. Convert it to a hash and render with the appropriate HTTP status:

```ruby
render json: result.to_h, status: result.success ? :created : :unprocessable_entity
```

### 3. Response format

All responses follow this shape (enforced by the Base service):

```json
// Success
{ "success": true, "data": { ... }, "message": "Widget created successfully" }

// Failure
{ "success": false, "errors": { "base": ["Translated error message"] } }
```

## HTTP Status Code Conventions

| Action | Success | Failure |
|--------|---------|---------|
| index | `:ok` (200) | `:unprocessable_entity` (422) |
| show | `:ok` (200) | `:not_found` (404) |
| create | `:created` (201) | `:unprocessable_entity` (422) |
| update | `:ok` (200) | `:unprocessable_entity` (422) |
| destroy | `:ok` (200) | `:unprocessable_entity` (422) |
| auth failure | — | `:unauthorized` (401) |
| permission denied | — | `:forbidden` (403) |

## Strong Parameters

Use `params.require(:resource).permit(...)` for create/update. Array columns use the `tags: []` syntax:

```ruby
def widget_params
  params.require(:widget).permit(
    :name, :code, :status, :description,
    :organisation_uid, :widget_type,
    tags: [], metadata: {}
  )
end
```

## Current User Context

Controllers extract user context from the decoded JWT and pass it to services:

```ruby
def current_user_params
  { org_uid: @decode['org_uid'], user_uid: @current_user&.uid }
end
```

Services receive this as `current_user` and use it for scoping queries to the right organisation.

## Collection Actions (Custom Endpoints)

For non-RESTful actions (dropdowns, bulk operations, custom queries), add collection routes:

```ruby
# In the controller
def dropdown_data
  result = WidgetService::DropdownData.new(params, current_user_params).call
  render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
end

def bulk_create
  result = WidgetService::BulkCreate.new(params, current_user_params).call
  render json: result.to_h, status: result.success ? :created : :unprocessable_entity
end

def bulk_template
  result = WidgetService::BulkTemplate.new(params, current_user_params).call
  send_data result.data, filename: result.filename, type: result.content_type
end
```

## Multi-Step Form Actions

Some resources use step-based creation where each step saves partial data:

```ruby
def create_widget
  result = WidgetService::Create.new(params, current_user_params, step: params[:step]).call
  render json: result.to_h, status: result.success ? :created : :unprocessable_entity
end

def update_widget
  result = WidgetService::Update.new(params, current_user_params, step: params[:step]).call
  render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
end
```

## Skipping Auth for Specific Actions

If an action needs to be public (rare in this project):

```ruby
skip_before_action :authenticate, only: [:public_action]
skip_before_action :authorize_action, only: [:public_action]
```

## Checklist Before Writing a Controller

1. Is it namespaced under `Api::V1::`?
2. Does it inherit from `ApplicationController`?
3. Does every action delegate to a service?
4. Is the response rendered with `result.to_h` and correct HTTP status?
5. Are strong parameters defined for create/update?
6. Is `current_user_params` passed to services?
7. Is `# frozen_string_literal: true` at the top?
8. Is business logic absent from the controller? (All logic lives in services)

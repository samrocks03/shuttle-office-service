---
name: rails-routes
description: "Write Rails routes following project conventions: api/v1 namespacing, JSON-only constraints, RESTful resources with collection routes for custom actions, multi-step form endpoints, bulk create/template patterns, and mounted engines. Use this skill whenever adding routes, creating new endpoints, or modifying config/routes.rb. Triggers on: 'add route', 'add endpoint', 'new resource route', 'collection route', 'routes.rb', 'API route', or any routing task."
---

# Rails Routing Patterns

All routes in this project are JSON-only API endpoints under the `api/v1` namespace. The routing file follows consistent patterns for RESTful resources, custom collection actions, and bulk operations.

## Base Structure

```ruby
# frozen_string_literal: true

require 'sidekiq/web'

Rails.application.routes.draw do
  mount Sidekiq::Web => '/sidekiq'
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  namespace 'api' do
    namespace 'v1' do
      # All resource routes go here
    end
  end
end
```

Every resource route lives inside the `api/v1` namespace block.

## Standard RESTful Resource

The simplest form — all CRUD actions with JSON constraint:

```ruby
resources :widgets, constraints: { format: :json }
```

To limit actions:

```ruby
resources :widgets, only: %i[index show create update], constraints: { format: :json }
resources :widgets, except: :destroy, constraints: { format: :json }
```

The `constraints: { format: :json }` is required on every resource. It ensures the API only accepts and returns JSON.

## Collection Routes (Custom Actions)

Non-RESTful actions use `collection` blocks. These generate paths like `/api/v1/widgets/dropdown_data` without an `:id` parameter:

```ruby
resources :widgets, constraints: { format: :json } do
  collection do
    get '/dropdown_data' => :dropdown_data
    get '/check_uniqueness' => :check_uniqueness
    post '/bulk_create/:type' => :bulk_create
    get '/bulk_template/:type' => :bulk_template
  end
end
```

### Common Collection Route Patterns

**Dropdown/list endpoints** — return simplified data for UI selects:
```ruby
get '/dropdown_data' => :dropdown_data
get '/program_list' => :program_list
get '/employees_list' => :employees_list
```

**Bulk operations** — Excel import/export with a `:type` parameter:
```ruby
post '/bulk_create/:type' => :bulk_create
get '/bulk_template/:type' => :bulk_template
# or without type:
get :bulk_template
post '/bulk_create/:type' => :bulk_create
```

**Check/validation endpoints**:
```ruby
get '/check_uniqueness' => :check_uniqueness
get '/check_destroy' => :check_destroy
```

**Custom actions**:
```ruby
patch '/freeze/:id' => :freeze_widget
put '/reorder' => :reorder
post '/send_invitations' => :send_invitations
get :download_report
```

## Multi-Step Form Routes

Resources with wizard-style creation use step-based routes:

```ruby
resources :programs, constraints: { format: :json } do
  collection do
    post 'step/:step' => :create_program
    put 'step/:step/:id' => :update_program
    patch 'close_program/:id' => :close_program
  end
end
```

This generates paths like `POST /api/v1/programs/step/1` and `PUT /api/v1/programs/step/2/abc-uid`.

## Nested Resources

For resources that belong under another:

```ruby
resources :courses, constraints: { format: :json } do
  collection do
    resources :elective_buckets, constraints: { format: :json } do
      collection do
        post 'elective_bucket_clone', to: 'elective_buckets#elective_bucket_clone'
      end
    end
  end
end
```

## Standalone Routes

For single-action endpoints that don't fit the resource pattern:

```ruby
get '/regions', to: 'regions#index'
get '/system_constant', to: 'system_constants#system_constant'
get '/check_uniqueness' => 'check_uniqueness#check_uniqueness'
get '/bank_lists', to: 'bank_lists#index'
```

## Collection-Only Update

When update doesn't use a standard `:id` param (e.g., updating by a different identifier):

```ruby
resources :addresses, constraints: { format: :json } do
  collection do
    put '/' => :update
  end
end

resources :term_durations, constraints: { format: :json } do
  collection do
    put '/' => :update
  end
end
```

## Route Naming Conventions

| Pattern | HTTP Method | Example Path |
|---------|-------------|--------------|
| Standard CRUD | GET/POST/PUT/DELETE | `/api/v1/widgets`, `/api/v1/widgets/:id` |
| Dropdown data | GET | `/api/v1/widgets/dropdown_data` |
| Bulk template | GET | `/api/v1/widgets/bulk_template/:type` |
| Bulk create | POST | `/api/v1/widgets/bulk_create/:type` |
| Multi-step create | POST | `/api/v1/widgets/step/:step` |
| Multi-step update | PUT | `/api/v1/widgets/step/:step/:id` |
| Custom action | PATCH/POST | `/api/v1/widgets/freeze/:id` |

## Adding a New Resource (Complete Example)

```ruby
resources :widgets, constraints: { format: :json } do
  collection do
    get '/fetch_dropdown_data' => :fetch_dropdown_data
    get :bulk_template
    post '/bulk_create/:type' => :bulk_create
    get '/check_uniqueness' => :check_uniqueness
  end
end
```

## Checklist Before Adding Routes

1. Is the resource inside the `api/v1` namespace?
2. Does it have `constraints: { format: :json }`?
3. Are custom actions in a `collection` block?
4. Are bulk endpoints following the `bulk_create/:type` and `bulk_template/:type` pattern?
5. Do routes use the correct HTTP verbs? (GET for reads, POST for creates, PUT/PATCH for updates)
6. Is the route not duplicated? (Check existing routes first)

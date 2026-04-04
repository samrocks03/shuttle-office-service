---
name: rails-service
description: "Write Rails service objects following the project's Base service pattern: module-namespaced classes inheriting from Base, chain-style call methods with early returns, OpenStruct responses, ActiveRecord transactions, I18n message keys, and serialized data output. Use this skill whenever creating service classes for CRUD operations, business logic, or any work in app/services/. Triggers on: 'create service', 'add service', 'service object', 'business logic', 'new service file', 'call method', or any task involving app/services/."
---

# Rails Service Object Patterns

Services encapsulate all business logic in this project. They inherit from a shared `Base` class that provides error handling, response building, and I18n integration. Every controller action delegates to a service -- controllers never contain business logic.

## Architecture Overview

Services are organized as module-namespaced classes:

```
app/services/
  base.rb                          # Shared superclass
  widget_service/
    index.rb                       # WidgetService::Index
    create.rb                      # WidgetService::Create
    update.rb                      # WidgetService::Update
    destroy.rb                     # WidgetService::Destroy
    show.rb                        # WidgetService::Show
    bulk_create.rb                 # WidgetService::BulkCreate (if XL import)
```

Each operation is its own class. This keeps files small and responsibilities clear.

## The Base Class

All services inherit from `Base`, which provides:

- `@errors` — `ActiveModel::Errors` instance for collecting errors
- `@data` — hash for response payload
- `@message` — string for success messages
- `add_error(key, params)` — adds a translated error from I18n
- `set_response` — builds the final `OpenStruct` (checks errors, returns success or failure)
- `success_response(data, message)` — shorthand for successful responses
- `failure_response(data)` — shorthand for failure responses
- `translate(key, params)` — wraps `I18n.t`
- `sanitize_sql_like(string)` — escapes SQL LIKE wildcards

The response format is always:

```ruby
# Success
OpenStruct.new(success: true, data: {...}, message: "Translated message")

# Failure
OpenStruct.new(success: false, errors: { base: ["Translated error"] }, ...)
```

## Service Skeleton: Index (Read/List)

```ruby
# frozen_string_literal: true

module WidgetService
  class Index < Base
    attr_accessor :result, :current_user, :widgets, :type

    SUCCESS_KEY = 'widget.index.success.message'

    def initialize(params, current_user)
      super()
      @type = params[:type]&.to_s&.downcase == 'f'
      @current_user = current_user
    end

    def call
      fetch_widgets &&
        (type ? set_data_for_front_end : set_data) &&
        set_response
    end

    private

    def fetch_widgets
      @widgets = WidgetRepository.fetch_widgets(current_user[:org_uid])
    end

    def set_data
      @data = V1::WidgetSerializer.new(widgets).serializable_hash
      @message = translate(SUCCESS_KEY)
    end

    def set_data_for_front_end
      widget_list = widgets&.map { |w| [w.uid, w.name] }.to_h
      @result = { widget_list: }
      @data = { data: generate_array_of_hash }
      @message = translate(SUCCESS_KEY)
    end
  end
end
```

## Service Skeleton: Create

```ruby
# frozen_string_literal: true

module WidgetService
  class Create < Base
    attr_reader :params, :current_user, :widget

    SUCCESS_KEY = 'widget.create.success.message'

    def initialize(params, current_user)
      super()
      @params = params.to_h.symbolize_keys
      @current_user = current_user
    end

    def call
      result = ActiveRecord::Base.transaction do
        create_widget &&
          set_data &&
          set_response
      end

      result || set_response
    end

    private

    def create_widget
      @widget = Widget.new(widget_params)
      return true if widget.save

      add_error('widget.create.failure', message: widget.errors.full_messages.join(', '))
      false
    end

    def widget_params
      {
        name: params[:name],
        code: params[:code],
        organisation_uid: current_user[:org_uid],
        status: params[:status] || 'active'
      }
    end

    def set_data
      @data = V1::WidgetSerializer.new(widget).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
```

## Service Skeleton: Update

```ruby
# frozen_string_literal: true

module WidgetService
  class Update < Base
    attr_reader :params, :current_user, :widget

    SUCCESS_KEY = 'widget.update.success.message'

    def initialize(params, current_user)
      super()
      @params = params.to_h.symbolize_keys
      @current_user = current_user
    end

    def call
      result = ActiveRecord::Base.transaction do
        find_widget &&
          update_widget &&
          set_data &&
          set_response
      end

      result || set_response
    end

    private

    def find_widget
      @widget = WidgetRepository.find_by_column(:uid, params[:id])
      return true if widget

      add_error('widget.not_found')
      false
    end

    def update_widget
      return true if widget.update(widget_params)

      add_error('widget.update.failure', message: widget.errors.full_messages.join(', '))
      false
    end

    def widget_params
      params.slice(:name, :code, :status)
    end

    def set_data
      @data = V1::WidgetSerializer.new(widget.reload).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
```

## Service Skeleton: Destroy

```ruby
# frozen_string_literal: true

module WidgetService
  class Destroy < Base
    attr_reader :params, :current_user, :widget

    SUCCESS_KEY = 'widget.destroy.success.message'

    def initialize(params, current_user)
      super()
      @params = params.to_h.symbolize_keys
      @current_user = current_user
    end

    def call
      find_widget &&
        destroy_widget &&
        set_response
    end

    private

    def find_widget
      @widget = WidgetRepository.find_by_column(:uid, params[:id])
      return true if widget

      add_error('widget.not_found')
      false
    end

    def destroy_widget
      return true if widget.destroy

      add_error('widget.destroy.failure')
      false
    end

    def set_response
      return super if errors.present?

      @message = translate(SUCCESS_KEY)
      super
    end
  end
end
```

## The Call Chain Pattern (Early Returns)

The `call` method chains private methods with `&&`. Each method returns `true` on success or `false` on failure (after calling `add_error`). This creates natural early returns -- if any step fails, the chain stops and `set_response` picks up the errors:

```ruby
def call
  step_one &&
    step_two &&
    step_three &&
    set_response
end
```

When using transactions, wrap the chain and fall back to `set_response` if the transaction returns nil (from a rollback):

```ruby
def call
  result = ActiveRecord::Base.transaction do
    step_one &&
      step_two &&
      set_response
  end

  result || set_response
end
```

## I18n Keys

Every service defines `SUCCESS_KEY` and references error keys via `add_error`. The key structure in `config/locales/en.yml`:

```yaml
en:
  widget:
    create:
      success:
        message: "Widget created successfully"
      failure:
        detail: "Failed to create widget: %{message}"
    update:
      success:
        message: "Widget updated successfully"
      failure:
        detail: "Failed to update widget: %{message}"
    destroy:
      success:
        message: "Widget deleted successfully"
      failure:
        detail: "Failed to delete widget"
    not_found:
      detail: "Widget not found"
    index:
      success:
        message: "Widgets fetched successfully"
```

## Key Rules

1. Always call `super()` in `initialize` (initializes `@errors`, `@data`, `@message`)
2. Use `attr_reader` for params set once in initialize, `attr_accessor` for mutable state
3. Private methods return `true`/`false` for the chain pattern
4. Wrap create/update in `ActiveRecord::Base.transaction`
5. Use the repository layer for queries, not direct ActiveRecord in services
6. Serialize output with `V1::*Serializer` before setting `@data`
7. Every user-facing string goes through I18n
8. Define `SUCCESS_KEY` as a constant at the top of each service class

## Checklist Before Writing a Service

1. Is it namespaced under `<Entity>Service::<Action>`?
2. Does `initialize` call `super()`?
3. Does `call` use the chain pattern with `&&`?
4. Are create/update operations wrapped in a transaction?
5. Do failure paths call `add_error` and return `false`?
6. Is `SUCCESS_KEY` defined and used?
7. Is data serialized before assignment to `@data`?
8. Are locale keys added to `config/locales/en.yml`?

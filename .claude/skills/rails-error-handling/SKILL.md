---
name: rails-error-handling
description: "Handle errors following project conventions: I18n translation keys for all error messages, add_error with key paths, ErrorMessageSerializer for formatted error responses, early return patterns in service chains, and standardized error response shapes. Use this skill whenever adding error handling, writing error messages, setting up locale keys, or debugging error flows. Triggers on: 'error handling', 'add_error', 'error message', 'locale key', 'i18n error', 'failure response', 'error response', 'early return', 'validation error', or any error-related work."
---

# Rails Error Handling Patterns

Errors in this project flow through a consistent pipeline: I18n locale keys define all messages, `add_error` collects them on the service, `ErrorMessageSerializer` formats them, and `set_response` decides whether to return success or failure. No error message is ever hardcoded in Ruby.

## The Error Flow

```
Service method fails
  → add_error('entity.action.failure', message: details)
    → errors.add(:base, I18n.t('entity.action.failure.detail', message: details))
      → set_response detects errors.present?
        → serialize_errors(key) formats via ErrorMessageSerializer
          → Controller renders { success: false, errors: { base: [...] } }
```

## add_error

The primary way to register an error in any service:

```ruby
add_error('widget.create.failure', message: widget.errors.full_messages.join(', '))
```

This method:
1. Stores the key for later serialization
2. Translates the key via I18n, interpolating any params
3. Adds the translated message to `errors` (ActiveModel::Errors)

```ruby
# In Base class
def add_error(key, params = {})
  @key = key
  errors.add(:base, translate("#{key}.detail", **params))
end
```

## I18n Locale Key Structure

All error (and success) messages live in `config/locales/en.yml` following this hierarchy:

```yaml
en:
  # Entity-level grouping
  widget:
    # Action-level grouping
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

  # Global exception key
  exception:
    errors:
      detail: "An unexpected error occurred: %{message}"

  # Authentication errors
  authentication:
    errors:
      unauthorized:
        detail: "You are not authorized to perform this action"
      unauthorized_action:
        detail: "You do not have permission for this action"
```

Key naming rules:
- Success messages end in `.success.message`
- Error messages end in `.failure.detail` or `.detail`
- Interpolation uses `%{variable_name}` syntax
- Every entity/action combination gets its own key path

## The Early Return Chain Pattern

Services chain methods with `&&`. Each method returns `true` to continue or `false` to stop (after calling `add_error`):

```ruby
def call
  find_widget &&
    validate_permissions &&
    update_widget &&
    set_data &&
    set_response
end

private

def find_widget
  @widget = WidgetRepository.find_by_column(:uid, params[:id])
  return true if widget

  add_error('widget.not_found')
  false
end

def validate_permissions
  return true if current_user[:org_uid] == widget.organisation_uid

  add_error('authentication.errors.unauthorized_action')
  false
end

def update_widget
  return true if widget.update(widget_params)

  add_error('widget.update.failure', message: widget.errors.full_messages.join(', '))
  false
end
```

When any method returns `false`, the `&&` chain short-circuits. `set_response` is only reached if ALL preceding methods succeed. But if you call `set_response` directly (outside the chain), it checks `errors.present?` and returns the failure response.

## Transaction Error Handling

Wrap mutations in a transaction with a fallback to `set_response`:

```ruby
def call
  result = ActiveRecord::Base.transaction do
    create_widget &&
      create_parts &&
      set_data &&
      set_response
  end

  # If transaction rolled back (returned nil), set_response picks up errors
  result || set_response
end
```

Why `result || set_response`? If `create_widget` returns `false`, it also calls `add_error`. The transaction block evaluates to `nil` (falsy). The `||` then calls `set_response`, which finds the errors and returns the failure response.

## set_response

The response builder checks for errors and formats accordingly:

```ruby
def set_response
  return OpenStruct.new(success: false, **serialize_errors(key)) if errors.present?
  OpenStruct.new(success: true, **data, message:)
end
```

## ErrorMessageSerializer

Formats errors for the API response:

```ruby
module V1
  class ErrorMessageSerializer
    def initialize(errors, key)
      @errors = errors
      @key = key
    end

    def serialized_json
      { errors: { base: @errors.full_messages }, error_key: @key }
    end
  end
end
```

The response shape is always:

```json
{
  "success": false,
  "errors": { "base": ["Translated error message"] },
  "error_key": "widget.create.failure"
}
```

## Exception Key

For unexpected errors (rescued exceptions), use the global exception key:

```ruby
EXCEPTION_KEY = 'exception.errors'

rescue ArgumentError => e
  add_error(EXCEPTION_KEY, message: e.message)
end
```

## Multi-Language Support

The project supports multiple locales (en, hi, de). Errors are automatically translated based on the user's locale preference, which is set by `switch_locale` in `ApplicationController`. So the same error key renders in different languages based on user preference.

## Checklist for Error Handling

1. Is every error message defined in `config/locales/en.yml`?
2. Does the error key follow the `entity.action.failure.detail` pattern?
3. Does the method call `add_error` then `return false`?
4. Are transactions using `result || set_response` for fallback?
5. Are interpolation variables matching between `add_error` params and locale `%{...}` placeholders?
6. For multi-language support, is the key also in `hi.yml` and `de.yml`?

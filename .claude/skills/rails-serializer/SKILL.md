---
name: rails-serializer
description: "Write JSONAPI::Serializer classes following project conventions: V1-namespaced serializers with attribute declarations, computed attribute blocks, nested serializer composition, and consistent naming. Use this skill whenever creating serializers, formatting API responses, or working on JSON output. Triggers on: 'create serializer', 'add serializer', 'serialize', 'JSON response format', 'API response', 'jsonapi', or any work in app/serializers/."
---

# Rails Serializer Patterns

This project uses `jsonapi-serializer` (the maintained fork of fast_jsonapi) for all API response formatting. Serializers live under the `V1` namespace and control exactly what data appears in API responses.

## Location

```
app/serializers/v1/
  widget_serializer.rb
  organisation_serializer.rb
  error_message_serializer.rb
```

## Serializer Skeleton

```ruby
# frozen_string_literal: true

module V1
  class WidgetSerializer
    include JSONAPI::Serializer

    attributes :uid, :name, :code, :status, :description, :created_at, :updated_at

    # Computed attribute — transforms the raw value
    attribute :display_status do |widget|
      widget.status&.titleize
    end

    # Nested serializer — composes another serializer's output
    attribute :organisation do |widget|
      OrganisationSerializer.new(widget.organisation).as_json if widget.organisation
    end

    # Conditional attribute
    attribute :parts do |widget|
      PartSerializer.new(widget.parts).as_json if widget.parts.present?
    end

    # Array of simple values
    attribute :tags do |widget|
      widget.tags || []
    end
  end
end
```

## Key Conventions

### V1 Namespace

Every serializer is inside `module V1`. This allows future API versioning (V2, V3) without breaking existing serializers:

```ruby
module V1
  class WidgetSerializer
    include JSONAPI::Serializer
  end
end
```

### Simple Attributes

List columns that should be returned as-is:

```ruby
attributes :uid, :name, :code, :status, :created_at, :updated_at
```

### Computed Attributes

Use a block when the value needs transformation. The block receives the model instance:

```ruby
attribute :display_status do |widget|
  widget.status&.titleize
end

attribute :full_name do |widget|
  "#{widget.code} - #{widget.name}"
end
```

### Composed Serializers

When a response includes nested associations, use another serializer inside an attribute block:

```ruby
attribute :organisation do |widget|
  OrganisationSerializer.new(widget.organisation).as_json if widget.organisation
end

attribute :parts do |widget|
  PartSerializer.new(widget.parts).as_json if widget.parts.present?
end

attribute :address do |widget|
  AddressSerializer.new(widget.address).as_json if widget.address
end
```

Always guard with `if widget.association` or `if widget.association.present?` to avoid serializing nil.

### Using `.as_json` vs `.serializable_hash`

- `.serializable_hash` — returns the full JSONAPI structure (used in services when setting `@data`)
- `.as_json` — returns a plain hash (used when nesting inside another serializer)

```ruby
# In a service (top-level serialization)
@data = V1::WidgetSerializer.new(widget).serializable_hash

# In a serializer (nested composition)
attribute :parts do |widget|
  V1::PartSerializer.new(widget.parts).as_json
end
```

### Error Message Serializer

The project has a special serializer for error responses used by the Base service:

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

This is called internally by `Base#serialize_errors` — you rarely need to use it directly.

## Naming Convention

| Model | Serializer |
|-------|------------|
| Widget | `V1::WidgetSerializer` |
| Organisation | `V1::OrganisationSerializer` |
| College (subtype) | `V1::CollegeSerializer` |
| ErrorMessage | `V1::ErrorMessageSerializer` |

The file name is the snake_case version: `widget_serializer.rb`

## Polymorphic Serializer Selection

When different models need different serializers (like Organisation subtypes), use a helper method in the Base service:

```ruby
def organisation_serializer
  case org&.org_type
  when 'College'
    V1::CollegeSerializer
  when 'University'
    V1::UniversitySerializer
  else
    V1::OrganisationSerializer
  end
end
```

## Checklist Before Writing a Serializer

1. Is it namespaced under `V1`?
2. Does it `include JSONAPI::Serializer`?
3. Are simple columns listed with `attributes`?
4. Are transformed values using computed `attribute` blocks?
5. Are nested associations using composed serializers with nil guards?
6. Is `# frozen_string_literal: true` at the top?
7. Does the file live in `app/serializers/v1/`?

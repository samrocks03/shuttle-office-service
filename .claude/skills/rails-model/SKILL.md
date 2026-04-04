---
name: rails-model
description: "Write Rails ActiveRecord models following project conventions: UUID-based uid with UidGenerator concern, associations with explicit foreign/primary keys, integer enums with constants, PaperTrail audit trails, validations, scopes, and callbacks. Use this skill whenever creating a new model, adding associations, validations, enums, scopes, or callbacks. Triggers on: 'create model', 'add association', 'add validation', 'add enum', 'add scope', 'add callback', 'has_many', 'belongs_to', 'new model file', or any work in app/models/."
---

# Rails Model Patterns

This skill ensures every model follows the project's established conventions. Models inherit from `ApplicationRecord` and use UUID-based identification, explicit association keys, and audit trails.

## Model Skeleton

Every new model follows this structure, in this order:

```ruby
# frozen_string_literal: true

class Widget < ApplicationRecord
  # 1. Concerns
  include UidGenerator

  # 2. Audit trail
  has_paper_trail

  # 3. Constants (for enums, status mappings)
  WIDGET_STATUSES = { active: 0, inactive: 1, archived: 2 }.freeze

  # 4. Enums
  enum status: WIDGET_STATUSES

  # 5. Callbacks
  before_create :generate_uid

  # 6. Associations
  belongs_to :organisation, foreign_key: 'organisation_uid', primary_key: 'uid', inverse_of: :widgets
  has_many :parts, class_name: 'Part', foreign_key: 'widget_uid', primary_key: 'uid',
                   inverse_of: :widget, dependent: :destroy

  # 7. Validations
  validates :name, presence: true
  validates :code, presence: true, uniqueness: { scope: :organisation_uid }

  # 8. Scopes
  scope :active, -> { where(status: :active) }
  scope :by_organisation, ->(org_uid) { where(organisation_uid: org_uid) }

  # 9. Instance methods
  def display_name
    "#{code} - #{name}"
  end
end
```

## UidGenerator Concern

Every model includes `UidGenerator` and calls `generate_uid` as a `before_create` callback. This generates a `SecureRandom.uuid` for the `uid` column if it's blank:

```ruby
include UidGenerator
before_create :generate_uid
```

The concern lives at `app/models/concerns/uid_generator.rb` and works like this:

```ruby
module UidGenerator
  def generate_uid
    self.uid ||= SecureRandom.uuid if uid.blank?
  end
end
```

Never set `uid` manually in application code -- let the callback handle it.

## PaperTrail Audit

Every model includes `has_paper_trail` for version tracking. This integrates with the `ApplicationController` which sets `PaperTrail.request.whodunnit` to the current user's uid:

```ruby
has_paper_trail
```

Place this right after concerns, before constants.

## Associations

Because the project uses `uid` (UUID) instead of `id` as the logical primary key for cross-table references, every association must explicitly declare `foreign_key` and `primary_key`:

```ruby
# belongs_to
belongs_to :organisation, foreign_key: 'organisation_uid', primary_key: 'uid', inverse_of: :widgets

# has_many
has_many :parts, class_name: 'Part', foreign_key: 'widget_uid', primary_key: 'uid',
                 inverse_of: :widget, dependent: :destroy

# has_one
has_one :address, class_name: 'Address', foreign_key: 'addressable_uid', primary_key: 'uid',
                  inverse_of: :widget, dependent: :destroy
```

Key rules:
- Always specify `foreign_key` and `primary_key` (both should reference `uid` columns)
- Always specify `inverse_of` for bidirectional associations
- Always specify `dependent: :destroy` on `has_many` and `has_one` unless there's a reason not to
- Use `class_name` when the association name differs from the model name
- Foreign key naming: `<associated_model_singular>_uid`

## Enums

Enums use integer columns mapped through a frozen constant hash:

```ruby
WIDGET_STATUSES = { active: 0, inactive: 1, archived: 2 }.freeze
enum status: WIDGET_STATUSES
```

Why a constant? It's referenceable elsewhere (serializers, services, tests) and makes the integer mapping explicit. The constant name follows the pattern `<MODEL>_<COLUMN_PLURAL>`.

## Validations

Standard Rails validations. Common patterns in this project:

```ruby
validates :name, presence: true
validates :code, presence: true, uniqueness: { scope: :organisation_uid }
validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
validates :status, inclusion: { in: WIDGET_STATUSES.keys.map(&:to_s) }
```

Uniqueness validations that are scoped to an organisation use `scope: :organisation_uid`.

## Scopes

Define scopes for commonly filtered queries:

```ruby
scope :active, -> { where(status: :active) }
scope :by_organisation, ->(org_uid) { where(organisation_uid: org_uid) }
scope :recent, -> { order(created_at: :desc) }
scope :search_by_name, ->(query) { where('name ILIKE ?', "%#{query}%") }
```

Keep scopes simple -- complex queries belong in the Repository layer.

## Frozen String Literal

Every Ruby file starts with:

```ruby
# frozen_string_literal: true
```

## Checklist Before Writing a Model

1. Does it include `UidGenerator` and `before_create :generate_uid`?
2. Does it have `has_paper_trail`?
3. Do all associations have explicit `foreign_key`, `primary_key`, and `inverse_of`?
4. Are enums defined with frozen constant hashes?
5. Are uniqueness validations scoped to `organisation_uid` where appropriate?
6. Is `# frozen_string_literal: true` at the top?
7. Are `has_many`/`has_one` associations using `dependent: :destroy`?

---
name: rails-repository
description: "Write Rails repository classes following the project's query abstraction pattern: class-method-only classes in app/services/repositories/, encapsulating all ActiveRecord queries away from services and controllers. Use this skill whenever creating repository files, writing database queries, or adding query methods. Triggers on: 'create repository', 'add repository', 'add query method', 'find_by_column', 'fetch records', 'repository pattern', or any work in app/services/repositories/."
---

# Rails Repository Pattern

Repositories are the query abstraction layer in this project. They sit between services and ActiveRecord, encapsulating all database queries. Services never call ActiveRecord directly for reads -- they go through repositories.

## Why Repositories?

Services contain business logic. Repositories contain query logic. This separation means:
- Queries are reusable across multiple services
- Query optimization happens in one place
- Services stay focused on business rules, not SQL details
- Testing services doesn't require knowing query internals

## Repository Location

```
app/services/repositories/
  widget_repository.rb
  organisation_repository.rb
  employee_repository.rb
  system_constant_repository.rb
```

## Repository Skeleton

```ruby
# frozen_string_literal: true

class WidgetRepository
  def self.index(org_uid)
    Widget.where(organisation_uid: org_uid).order(:name)
  end

  def self.find_by_column(column, value)
    Widget.find_by(column => value)
  end

  def self.fetch_widgets(org_uid)
    Widget.where(organisation_uid: org_uid)
          .order(created_at: :desc)
  end

  def self.search(org_uid, query)
    Widget.where(organisation_uid: org_uid)
          .where('name ILIKE ?', "%#{query}%")
          .order(:name)
  end

  def self.find_by_uid(uid)
    Widget.find_by(uid: uid)
  end

  def self.exists?(column, value, org_uid)
    Widget.where(organisation_uid: org_uid)
          .exists?(column => value)
  end
end
```

## Key Conventions

### Class Methods Only

Repositories are stateless -- every method is a class method (`def self.method_name`). There's no reason to instantiate a repository:

```ruby
# Correct
WidgetRepository.find_by_column(:uid, some_uid)

# Wrong -- don't do this
WidgetRepository.new.find_by_column(:uid, some_uid)
```

### The `find_by_column` Pattern

Every repository has a generic finder that accepts any column name and value:

```ruby
def self.find_by_column(column, value)
  Widget.find_by(column => value)
end
```

This is the primary way services look up individual records. The column is typically `:uid`.

### Organisation Scoping

Most queries scope to an organisation via `organisation_uid`:

```ruby
def self.fetch_widgets(org_uid)
  Widget.where(organisation_uid: org_uid)
end
```

### Return Raw ActiveRecord

Repositories return ActiveRecord relations or model instances -- not serialized data, not hashes. Serialization is the service's job:

```ruby
# Repository returns a relation
def self.index(org_uid)
  Widget.where(organisation_uid: org_uid).order(:name)
end

# Service serializes it
widgets = WidgetRepository.index(current_user[:org_uid])
@data = V1::WidgetSerializer.new(widgets).serializable_hash
```

### Complex Queries

For joins, aggregations, or multi-table queries:

```ruby
def self.with_parts_count(org_uid)
  Widget.left_joins(:parts)
        .where(organisation_uid: org_uid)
        .group(:id)
        .select('widgets.*, COUNT(parts.id) AS parts_count')
        .order(:name)
end

def self.active_with_associations(org_uid)
  Widget.includes(:parts, :organisation)
        .where(organisation_uid: org_uid, status: :active)
        .order(:name)
end
```

Use `includes` for eager loading to prevent N+1 queries (the project uses Bullet and Prosopite gems to detect these).

### Dropdown/Frontend Data

Repositories often have methods that return simplified data for dropdowns:

```ruby
def self.dropdown_list(org_uid)
  Widget.where(organisation_uid: org_uid)
        .pluck(:uid, :name)
        .map { |uid, name| { value: uid, label: name } }
end
```

## Naming Conventions

| Method Pattern | Purpose |
|---|---|
| `index(org_uid)` | List all records for an org |
| `find_by_column(col, val)` | Find single record by any column |
| `find_by_uid(uid)` | Shorthand for find_by_column(:uid, uid) |
| `fetch_<entities>(org_uid)` | Fetch with specific ordering/filtering |
| `search(org_uid, query)` | Text search with ILIKE |
| `exists?(col, val, org_uid)` | Check existence |
| `dropdown_list(org_uid)` | Simplified data for UI dropdowns |

## Checklist Before Writing a Repository

1. Is it in `app/services/repositories/`?
2. Are all methods class methods (`def self.`)?
3. Does it return ActiveRecord objects (not serialized data)?
4. Are queries scoped to `organisation_uid` where appropriate?
5. Does it use `includes` for associations to prevent N+1?
6. Is `find_by_column` implemented?
7. Is `# frozen_string_literal: true` at the top?

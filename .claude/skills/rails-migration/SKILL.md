---
name: rails-migration
description: "Write Rails database migrations following project conventions: UUID primary keys with pgcrypto, named indexes, array columns, bulk mode, and proper column defaults. Use this skill whenever creating or modifying database tables, adding columns, creating indexes, or writing any ActiveRecord migration. Triggers on: 'create migration', 'add column', 'create table', 'add index', 'change column', 'database change', 'new migration', 'schema change', or any task that requires a db/migrate file."
---

# Rails Migration Patterns

This skill ensures every migration follows the project's established database conventions. The project uses PostgreSQL with UUID-based primary keys, and every table follows a consistent structure.

## Core Conventions

### UUID Primary Keys

Every table uses `uuid` as its primary identifier instead of auto-incrementing integers. This is a deliberate architectural choice for distributed-safe IDs and cross-service references.

Enable the `pgcrypto` extension at the top of any migration that creates a new table (idempotently):

```ruby
enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
```

Then define the `uid` column as a non-null UUID with a database-level default:

```ruby
t.uuid :uid, null: false, default: 'gen_random_uuid()'
```

Always add a unique index on `uid`:

```ruby
t.index :uid, name: 'index_<table_name>_on_uid', unique: true
```

### Bulk Mode

Use `bulk: true` on `create_table` to batch all column additions into a single ALTER TABLE statement. This is faster for PostgreSQL:

```ruby
create_table :widgets, bulk: true do |t|
  # columns here
end
```

### Naming Indexes

Always name indexes explicitly rather than relying on Rails auto-naming. The pattern is:

```
index_<table_name>_on_<column_name>
```

This prevents issues with index name length limits and makes migrations reversible with clarity.

### Foreign Keys as UUIDs

When referencing another table, use `t.uuid` with the naming convention `<associated_table_singular>_uid`:

```ruby
t.uuid :organisation_uid  # references organisations.uid
t.uuid :parent_org_uid    # references organisations.uid (self-referential)
```

Do NOT use `t.references` with UUID tables -- use explicit `t.uuid` columns and add indexes manually.

### Array Columns

PostgreSQL array columns are used for denormalized lists. Always provide a default of `[]`:

```ruby
t.string :sub_faculties, array: true, default: []
t.string :affiliation_types, array: true, default: []
```

### Integer Enums

Enum columns use `t.integer` with a default of `0` (the first enum value):

```ruby
t.integer :status, default: 0
t.integer :org_type
```

### Boolean Defaults

Boolean columns always have an explicit default:

```ruby
t.boolean :allow_view_only, default: false
t.boolean :is_active, default: true
```

### Timestamps

Every table includes timestamps:

```ruby
t.timestamps
```

## Complete Example: Creating a New Table

```ruby
# frozen_string_literal: true

class CreateWidgets < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    create_table :widgets, bulk: true do |t|
      t.uuid :uid, null: false, default: 'gen_random_uuid()'
      t.uuid :organisation_uid
      t.string :name
      t.string :code
      t.text :description
      t.integer :status, default: 0
      t.integer :widget_type
      t.boolean :is_active, default: true
      t.string :tags, array: true, default: []

      t.timestamps

      t.index :uid, name: 'index_widgets_on_uid', unique: true
      t.index :code, name: 'index_widgets_on_code', unique: true
      t.index :organisation_uid, name: 'index_widgets_on_organisation_uid'
    end
  end
end
```

## Adding Columns to Existing Tables

```ruby
# frozen_string_literal: true

class AddDetailsToWidgets < ActiveRecord::Migration[7.0]
  def change
    add_column :widgets, :priority, :integer, default: 0
    add_column :widgets, :metadata, :jsonb, default: {}
    add_index :widgets, :priority, name: 'index_widgets_on_priority'
  end
end
```

## Adding Unique Indexes

```ruby
# frozen_string_literal: true

class AddUniqueIndexToWidgets < ActiveRecord::Migration[7.0]
  def change
    add_index :widgets, %i[name organisation_uid],
              name: 'index_widgets_on_name_and_org_uid',
              unique: true
  end
end
```

## Migration File Naming

Rails generates the timestamp prefix automatically. The file name convention:

- New table: `create_<table_name>.rb`
- Add columns: `add_<column>_to_<table>.rb`
- Remove columns: `remove_<column>_from_<table>.rb`
- Add index: `add_unique_index_to_<table>.rb`
- Rename: `rename_<old>_to_<new>_in_<table>.rb`

## Checklist Before Writing a Migration

1. Does the table need a `uid` column? (Yes, always for new tables)
2. Are all foreign keys using `t.uuid` with `_uid` suffix?
3. Are indexes explicitly named?
4. Do boolean columns have defaults?
5. Do enum columns use `t.integer`?
6. Is `bulk: true` set on `create_table`?
7. Are array columns defaulting to `[]`?
8. Is `pgcrypto` extension enabled?

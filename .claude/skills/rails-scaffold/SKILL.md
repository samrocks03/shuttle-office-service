---
name: rails-scaffold
description: "Scaffold a complete new Rails API resource end-to-end: migration, model, repository, services (Index/Create/Update/Destroy/Show), serializer, controller, routes, locale keys, and factory. This is the master orchestration skill — use it whenever building a new resource from scratch. It references the individual skills (rails-migration, rails-model, etc.) for detailed conventions. Triggers on: 'scaffold', 'new resource', 'generate resource', 'create full resource', 'build CRUD', 'add new entity', 'new feature end to end', or any request to create a complete resource with all layers."
---

# Rails Full Resource Scaffold

This skill orchestrates the creation of a complete API resource across all layers. It acts as a checklist and file manifest — for the detailed conventions of each layer, consult the individual skills (rails-migration, rails-model, etc.).

## Files to Create

When scaffolding a new resource called `Widget`, create these files in order:

```
1. db/migrate/YYYYMMDDHHMMSS_create_widgets.rb          → rails-migration skill
2. app/models/widget.rb                                  → rails-model skill
3. app/services/repositories/widget_repository.rb        → rails-repository skill
4. app/services/widget_service/index.rb                  → rails-service skill
5. app/services/widget_service/show.rb                   → rails-service skill
6. app/services/widget_service/create.rb                 → rails-service skill
7. app/services/widget_service/update.rb                 → rails-service skill
8. app/services/widget_service/destroy.rb                → rails-service skill
9. app/serializers/v1/widget_serializer.rb               → rails-serializer skill
10. app/controllers/api/v1/widgets_controller.rb         → rails-controller skill
11. config/routes.rb (add resource)                      → rails-routes skill
12. config/locales/en.yml (add keys)                     → rails-error-handling skill
13. spec/factories/widgets.rb                            → rails-test skill
```

Optional (if bulk operations needed):
```
14. app/services/widget_service/bulk_template.rb         → rails-bulk-xl skill
15. app/services/widget_service/bulk_create.rb           → rails-bulk-xl skill
```

## Step-by-Step Scaffold

### Step 1: Migration

Create the table with UUID primary key, pgcrypto, named indexes, and bulk mode.

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_widgets.rb
class CreateWidgets < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    create_table :widgets, bulk: true do |t|
      t.uuid :uid, null: false, default: 'gen_random_uuid()'
      t.uuid :organisation_uid
      t.string :name
      t.string :code
      t.integer :status, default: 0
      t.timestamps

      t.index :uid, name: 'index_widgets_on_uid', unique: true
      t.index :organisation_uid, name: 'index_widgets_on_organisation_uid'
    end
  end
end
```

### Step 2: Model

```ruby
# app/models/widget.rb
class Widget < ApplicationRecord
  include UidGenerator
  has_paper_trail

  WIDGET_STATUSES = { active: 0, inactive: 1 }.freeze
  enum status: WIDGET_STATUSES

  before_create :generate_uid

  belongs_to :organisation, foreign_key: 'organisation_uid', primary_key: 'uid', inverse_of: :widgets

  validates :name, presence: true
end
```

### Step 3: Repository

```ruby
# app/services/repositories/widget_repository.rb
class WidgetRepository
  def self.index(org_uid)
    Widget.where(organisation_uid: org_uid).order(:name)
  end

  def self.find_by_column(column, value)
    Widget.find_by(column => value)
  end
end
```

### Step 4: Services

Create the service directory and individual operation files:

```bash
mkdir -p app/services/widget_service
```

Create `index.rb`, `show.rb`, `create.rb`, `update.rb`, `destroy.rb` following the rails-service skill patterns. Each inherits from `Base`, uses the `&&` chain pattern, and defines `SUCCESS_KEY`.

### Step 5: Serializer

```ruby
# app/serializers/v1/widget_serializer.rb
module V1
  class WidgetSerializer
    include JSONAPI::Serializer
    attributes :uid, :name, :code, :status, :created_at, :updated_at
  end
end
```

### Step 6: Controller

```ruby
# app/controllers/api/v1/widgets_controller.rb
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
        params.require(:widget).permit(:name, :code, :status)
      end

      def current_user_params
        { org_uid: @decode['org_uid'], user_uid: @current_user&.uid }
      end
    end
  end
end
```

### Step 7: Routes

Add to `config/routes.rb` inside the `api/v1` namespace block:

```ruby
resources :widgets, constraints: { format: :json }
```

### Step 8: Locale Keys

Add to `config/locales/en.yml`:

```yaml
widget:
  index:
    success:
      message: "Widgets fetched successfully"
  show:
    success:
      message: "Widget fetched successfully"
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
```

### Step 9: Factory

```ruby
# spec/factories/widgets.rb
FactoryBot.define do
  factory :widget do
    uid { SecureRandom.uuid }
    name { Faker::Commerce.product_name }
    code { Faker::Alphanumeric.unique.alphanumeric(number: 8).upcase }
    status { :active }
    organisation_uid { SecureRandom.uuid }
  end
end
```

## Post-Scaffold Checklist

After creating all files, verify:

- [ ] Migration can be run: `bundle exec rails db:migrate`
- [ ] Model loads without errors: `bundle exec rails runner "Widget.new"`
- [ ] Routes are accessible: `bundle exec rails routes | grep widget`
- [ ] All service files exist and inherit from Base
- [ ] Locale keys are present in en.yml
- [ ] Factory builds: `bundle exec rails runner "FactoryBot.build(:widget)"`
- [ ] Add the association to the Organisation model if needed

## Extending the Scaffold

If the resource needs additional features, add them using the appropriate skill:

- **Bulk operations**: Use rails-bulk-xl skill for BulkTemplate and BulkCreate services + routes
- **Background jobs**: Use rails-job skill for async processing
- **External service integration**: Use rails-external-service skill
- **Custom collection routes**: Use rails-routes skill for dropdown_data, check_uniqueness, etc.

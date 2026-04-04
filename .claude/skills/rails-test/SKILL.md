---
name: rails-test
description: "Write Rails tests following project conventions: RSpec with FactoryBot factories, Faker data generation, database_cleaner strategies, Rswag request specs for Swagger doc generation, shared examples, and SimpleCov coverage. Use this skill whenever writing tests, creating factories, adding specs, or working in the spec/ directory. Triggers on: 'write test', 'add spec', 'create factory', 'rspec', 'test case', 'request spec', 'swagger spec', 'rswag', or any testing task."
---

# Rails Testing Patterns

This project uses RSpec as the test framework with FactoryBot for test data, Faker for realistic values, and Rswag for Swagger documentation generation from request specs.

## Test Stack

- **RSpec 6.1** — test framework
- **FactoryBot** — test data factories
- **Faker** — realistic fake data generation
- **DatabaseCleaner** — test database cleanup between runs
- **Rswag** — generates Swagger/OpenAPI docs from request specs
- **SimpleCov** — code coverage (HTML/JSON/LCOV reports)
- **Bullet** — N+1 query detection in tests
- **Prosopite** — additional N+1 detection

## Directory Structure

```
spec/
  factories/
    widgets.rb
  models/
    widget_spec.rb
  requests/
    api/v1/widgets_spec.rb
  services/
    widget_service/
      create_spec.rb
      index_spec.rb
  repositories/
    widget_repository_spec.rb
  support/
    shared_examples/
    shared_contexts/
  rails_helper.rb
  spec_helper.rb
  swagger_helper.rb
```

## Factory Pattern

```ruby
# spec/factories/widgets.rb
# frozen_string_literal: true

FactoryBot.define do
  factory :widget do
    uid { SecureRandom.uuid }
    name { Faker::Commerce.product_name }
    code { Faker::Alphanumeric.unique.alphanumeric(number: 8).upcase }
    status { :active }
    description { Faker::Lorem.paragraph }
    organisation_uid { SecureRandom.uuid }
    tags { [Faker::Lorem.word, Faker::Lorem.word] }

    trait :inactive do
      status { :inactive }
    end

    trait :archived do
      status { :archived }
    end

    trait :with_parts do
      after(:create) do |widget|
        create_list(:part, 3, widget_uid: widget.uid)
      end
    end

    trait :with_organisation do
      association :organisation, factory: :organisation
      organisation_uid { organisation.uid }
    end
  end
end
```

Key conventions:
- Use `SecureRandom.uuid` for `uid` fields
- Use Faker for realistic data (not hardcoded strings)
- Define traits for common variations
- Use `after(:create)` for associated records
- Match foreign keys to the parent's `uid`

## Model Spec

```ruby
# spec/models/widget_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Widget, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:organisation).with_foreign_key('organisation_uid').with_primary_key('uid') }
    it { is_expected.to have_many(:parts).with_foreign_key('widget_uid').with_primary_key('uid').dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_uniqueness_of(:code).scoped_to(:organisation_uid) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(active: 0, inactive: 1, archived: 2) }
  end

  describe 'callbacks' do
    it 'generates uid before create' do
      widget = build(:widget, uid: nil)
      widget.save
      expect(widget.uid).to be_present
    end
  end

  describe '#display_name' do
    it 'returns code and name' do
      widget = build(:widget, code: 'WDG001', name: 'Test Widget')
      expect(widget.display_name).to eq('WDG001 - Test Widget')
    end
  end
end
```

## Service Spec

```ruby
# spec/services/widget_service/create_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WidgetService::Create do
  let(:organisation) { create(:organisation) }
  let(:current_user) { { org_uid: organisation.uid, user_uid: SecureRandom.uuid } }
  let(:valid_params) do
    {
      name: 'Test Widget',
      code: 'WDG001',
      status: 'active'
    }
  end

  describe '#call' do
    context 'with valid params' do
      it 'creates a widget and returns success' do
        result = described_class.new(valid_params, current_user).call

        expect(result.success).to be true
        expect(result.data).to be_present
        expect(Widget.count).to eq(1)
      end
    end

    context 'with missing required params' do
      it 'returns failure with errors' do
        result = described_class.new({ name: '' }, current_user).call

        expect(result.success).to be false
        expect(result.errors).to be_present
      end
    end

    context 'with duplicate code' do
      before { create(:widget, code: 'WDG001', organisation_uid: organisation.uid) }

      it 'returns failure' do
        result = described_class.new(valid_params, current_user).call

        expect(result.success).to be false
      end
    end
  end
end
```

## Repository Spec

```ruby
# spec/repositories/widget_repository_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WidgetRepository do
  let(:organisation) { create(:organisation) }

  describe '.index' do
    it 'returns widgets for the given organisation' do
      widget = create(:widget, organisation_uid: organisation.uid)
      create(:widget) # different org

      result = described_class.index(organisation.uid)

      expect(result).to contain_exactly(widget)
    end
  end

  describe '.find_by_column' do
    it 'finds a widget by the given column and value' do
      widget = create(:widget)

      result = described_class.find_by_column(:uid, widget.uid)

      expect(result).to eq(widget)
    end

    it 'returns nil when not found' do
      result = described_class.find_by_column(:uid, 'nonexistent')

      expect(result).to be_nil
    end
  end
end
```

## Rswag Request Spec (Swagger Generation)

```ruby
# spec/requests/api/v1/widgets_spec.rb
# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Widgets', type: :request do
  path '/api/v1/widgets' do
    get 'List widgets' do
      tags 'Widgets'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'widgets listed' do
        let(:Authorization) { "Bearer #{generate_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be true
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be false
        end
      end
    end

    post 'Create a widget' do
      tags 'Widgets'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :widget, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          code: { type: :string },
          status: { type: :string }
        },
        required: %w[name code]
      }

      response '201', 'widget created' do
        let(:Authorization) { "Bearer #{generate_token}" }
        let(:widget) { { name: 'New Widget', code: 'WDG001' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be true
        end
      end

      response '422', 'invalid request' do
        let(:Authorization) { "Bearer #{generate_token}" }
        let(:widget) { { name: '' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be false
        end
      end
    end
  end
end
```

## Running Tests

```bash
# Run all specs
bundle exec rspec

# Run a specific file
bundle exec rspec spec/services/widget_service/create_spec.rb

# Generate Swagger docs from request specs
bundle exec rake rswag:specs:swaggerize

# Run with coverage report
COVERAGE=true bundle exec rspec
```

## Test Data Conventions

- Use `let` for lazy-loaded test data (evaluated on first use)
- Use `let!` when records must exist before the test runs
- Use `create` for persisted records, `build` for in-memory
- Use `described_class` instead of repeating the class name
- Group tests with `context` blocks for different scenarios
- Name contexts with "with" or "when" prefixes

## Checklist Before Writing Tests

1. Is there a factory for the model being tested?
2. Does the factory use Faker for realistic data?
3. Are UUID fields using `SecureRandom.uuid`?
4. Are service specs testing both success and failure paths?
5. Are request specs generating Swagger documentation?
6. Is `# frozen_string_literal: true` at the top?
7. Is `require 'rails_helper'` (or `require 'swagger_helper'` for Rswag) present?

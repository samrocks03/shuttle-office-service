---
name: rails-bulk-xl
description: "Write Excel import/export functionality following project conventions: caxlsx for XLSX generation (bulk_template), roo for XLSX/CSV parsing (bulk_create), service-based processing, type-parameterized endpoints, and error collection per row. Use this skill whenever implementing Excel export, Excel import, bulk operations, CSV processing, spreadsheet templates, or download features. Triggers on: 'excel', 'xlsx', 'csv', 'bulk create', 'bulk template', 'import', 'export', 'spreadsheet', 'download template', 'bulk upload', or any XL/bulk work."
---

# Rails Excel / Bulk Operations Patterns

This project uses `caxlsx` for generating Excel files (templates/exports) and `roo` for reading uploaded Excel/CSV files (bulk imports). Bulk operations follow a template-download-then-upload workflow.

## Gems

- **caxlsx 3.0** — generates `.xlsx` files (Axlsx wrapper with streaming support)
- **roo 2.10** — reads `.xlsx`, `.xls`, `.csv` files into Ruby objects

## The Bulk Workflow

1. User downloads a template via `GET /api/v1/widgets/bulk_template/:type`
2. User fills in data in the spreadsheet
3. User uploads via `POST /api/v1/widgets/bulk_create/:type`
4. Service parses the file, validates each row, creates records, and reports errors

The `:type` parameter distinguishes between different template/import formats for the same resource (e.g., `f` for frontend-formatted).

## Routes

```ruby
resources :widgets, constraints: { format: :json } do
  collection do
    get 'bulk_template/:type' => :bulk_template
    post '/bulk_create/:type' => :bulk_create
  end
end
```

## Controller Actions

```ruby
def bulk_template
  result = WidgetService::BulkTemplate.new(params, current_user_params).call
  if result.success
    send_data result.data[:file_data],
              filename: result.data[:filename],
              type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  else
    render json: result.to_h, status: :unprocessable_entity
  end
end

def bulk_create
  result = WidgetService::BulkCreate.new(params, current_user_params).call
  render json: result.to_h, status: result.success ? :created : :unprocessable_entity
end
```

## Bulk Template Service (Excel Generation with caxlsx)

```ruby
# frozen_string_literal: true

module WidgetService
  class BulkTemplate < Base
    attr_reader :params, :current_user

    def initialize(params, current_user)
      super()
      @params = params
      @current_user = current_user
    end

    def call
      generate_template &&
        set_response
    end

    private

    def generate_template
      package = Axlsx::Package.new
      workbook = package.workbook

      # Header style
      header_style = workbook.styles.add_style(
        b: true, bg_color: '4472C4', fg_color: 'FFFFFF',
        alignment: { horizontal: :center },
        border: { style: :thin, color: '000000' }
      )

      workbook.add_worksheet(name: 'Widgets') do |sheet|
        # Header row
        sheet.add_row headers, style: header_style

        # Optional: add sample data row
        sheet.add_row sample_row

        # Column widths
        sheet.column_widths(*column_widths)
      end

      # Add a validation/dropdown sheet if needed
      add_dropdown_sheet(workbook) if dropdown_data.present?

      @data = {
        data: {
          file_data: package.to_stream.read,
          filename: "widget_template_#{Date.today}.xlsx"
        }
      }
      @message = translate('widget.bulk_template.success.message')
    end

    def headers
      ['Name*', 'Code*', 'Status', 'Description', 'Tags (comma-separated)']
    end

    def sample_row
      ['Example Widget', 'WDG001', 'active', 'Sample description', 'tag1, tag2']
    end

    def column_widths
      [30, 15, 15, 40, 30]
    end

    def add_dropdown_sheet(workbook)
      workbook.add_worksheet(name: 'Dropdowns') do |sheet|
        dropdown_data.each_with_index do |value, i|
          sheet.add_row [value]
        end
      end
    end

    def dropdown_data
      Widget::WIDGET_STATUSES.keys.map(&:to_s)
    end
  end
end
```

## Bulk Create Service (Excel Parsing with roo)

```ruby
# frozen_string_literal: true

module WidgetService
  class BulkCreate < Base
    attr_reader :params, :current_user, :file, :row_errors

    SUCCESS_KEY = 'widget.bulk_create.success.message'

    def initialize(params, current_user)
      super()
      @params = params
      @current_user = current_user
      @file = params[:file]
      @row_errors = []
    end

    def call
      validate_file &&
        parse_and_create &&
        set_response
    end

    private

    def validate_file
      unless file.present?
        add_error('widget.bulk_create.file_missing')
        return false
      end

      extension = File.extname(file.original_filename).downcase
      unless %w[.xlsx .csv].include?(extension)
        add_error('widget.bulk_create.invalid_format')
        return false
      end

      true
    end

    def parse_and_create
      spreadsheet = open_spreadsheet
      header = spreadsheet.row(1).map(&:to_s).map(&:strip).map(&:downcase)

      results = ActiveRecord::Base.transaction do
        (2..spreadsheet.last_row).each do |i|
          row = Hash[[header, spreadsheet.row(i)].transpose]
          create_from_row(row, i)
        end

        if row_errors.any?
          add_error('widget.bulk_create.partial_failure',
                    message: "#{row_errors.length} rows failed")
          raise ActiveRecord::Rollback
        end

        true
      end

      results || false
    end

    def create_from_row(row, row_number)
      widget = Widget.new(
        name: row['name'],
        code: row['code'],
        status: row['status'] || 'active',
        description: row['description'],
        organisation_uid: current_user[:org_uid]
      )

      unless widget.save
        row_errors << { row: row_number, errors: widget.errors.full_messages }
      end
    end

    def open_spreadsheet
      case File.extname(file.original_filename).downcase
      when '.csv'  then Roo::CSV.new(file.path)
      when '.xlsx' then Roo::Excelx.new(file.path)
      else raise "Unknown file type: #{file.original_filename}"
      end
    end

    def set_data
      @data = {
        data: {
          created_count: spreadsheet_row_count - 1 - row_errors.length,
          error_count: row_errors.length,
          row_errors: row_errors
        }
      }
      @message = translate(SUCCESS_KEY)
    end
  end
end
```

## Key Patterns

### Template Styling

Use `Axlsx` styles for professional templates:

```ruby
header_style = workbook.styles.add_style(
  b: true,                                    # Bold
  bg_color: '4472C4',                         # Blue background
  fg_color: 'FFFFFF',                         # White text
  alignment: { horizontal: :center },
  border: { style: :thin, color: '000000' }
)
```

### Row-Level Error Collection

Don't fail on first error. Collect all row errors and report them:

```ruby
row_errors << { row: row_number, errors: widget.errors.full_messages }
```

### File Type Detection

Always detect by extension and use the appropriate Roo parser:

```ruby
case File.extname(file.original_filename).downcase
when '.csv'  then Roo::CSV.new(file.path)
when '.xlsx' then Roo::Excelx.new(file.path)
end
```

### Header Normalization

Normalize headers from the uploaded file for reliable column matching:

```ruby
header = spreadsheet.row(1).map(&:to_s).map(&:strip).map(&:downcase)
```

## Checklist Before Writing Bulk Operations

1. Is `bulk_template` generating with caxlsx (`Axlsx::Package`)?
2. Is `bulk_create` parsing with roo (`Roo::Excelx` / `Roo::CSV`)?
3. Are routes using `bulk_template/:type` and `bulk_create/:type`?
4. Does the controller use `send_data` for file downloads?
5. Are row-level errors collected (not failing on first error)?
6. Is the file type validated before parsing?
7. Are headers normalized (downcase, strip)?
8. Is creation wrapped in a transaction with rollback on errors?

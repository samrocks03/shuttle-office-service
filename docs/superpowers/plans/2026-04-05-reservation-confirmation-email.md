# Reservation Confirmation Email Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a reservation is created, a Sidekiq background job generates a professional PDF boarding pass and emails it to the user via ActionMailer.

**Architecture:** Service-object PDF generation with an abstract base class (`Pdf::BaseGenerator`) that subclasses extend. A Sidekiq job orchestrates PDF generation and email delivery. The model is kept clean — no callbacks for side effects.

**Tech Stack:** Rails 7.0, Prawn 2.5 (PDF), Sidekiq 7 (jobs), Redis (queue backend), Letter Opener (dev email preview), ActionMailer

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `Gemfile` | Modify | Add sidekiq, letter_opener gems |
| `config/sidekiq.yml` | Create | Sidekiq queue configuration |
| `config/application.rb` | Modify | Set Active Job queue adapter to :sidekiq |
| `config/environments/development.rb` | Modify | Letter Opener as delivery method |
| `app/services/pdf/base_generator.rb` | Create | Abstract PDF base: header, footer, section, info_row, divider |
| `app/services/pdf/reservation_generator.rb` | Create | Reservation-specific PDF with ticket-style layout |
| `app/mailers/reservation_mailer.rb` | Create | Composes confirmation email, attaches PDF |
| `app/views/layouts/mailer.html.erb` | Modify | Proper HTML5 email layout with reset styles |
| `app/views/reservation_mailer/confirmation.html.erb` | Create | Inline-styled HTML email template |
| `app/views/reservation_mailer/confirmation.text.erb` | Create | Plain text email fallback |
| `app/jobs/reservation_confirmation_job.rb` | Create | Async orchestrator: generate PDF → send email |
| `app/models/reservation.rb` | Modify | Remove old `after_create` PDF callback |
| `app/services/reservation_service/create.rb` | Modify | Enqueue job after successful transaction |

---

### Task 1: Add Dependencies & Configuration

**Files:**
- Modify: `Gemfile`
- Create: `config/sidekiq.yml`
- Modify: `config/application.rb`
- Modify: `config/environments/development.rb`

- [ ] **Step 1: Add sidekiq and letter_opener to Gemfile**

Open `Gemfile` and add the following. Place `sidekiq` near the other runtime gems (after the `redis` gem on line 44), and `letter_opener` inside the existing `group :development` block (line 79):

After the line `gem "redis", ">= 4.0.1"` add:

```ruby
gem 'sidekiq', '~> 7.0'
```

Inside `group :development do` (line 79), add:

```ruby
gem 'letter_opener'
```

- [ ] **Step 2: Create Sidekiq queue configuration**

Create `config/sidekiq.yml`:

```yaml
---
:concurrency: 5
:queues:
  - default
  - mailers
```

- [ ] **Step 3: Set Active Job queue adapter**

In `config/application.rb`, inside the `class Application < Rails::Application` block, after the line `config.middleware.use ActionDispatch::Cookies` (line 39), add:

```ruby
    config.active_job.queue_adapter = :sidekiq
```

- [ ] **Step 4: Configure Letter Opener for development**

In `config/environments/development.rb`, find the mailer config section. Replace:

```ruby
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false
```

With:

```ruby
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :letter_opener
  config.action_mailer.perform_deliveries = true
```

- [ ] **Step 5: Install gems**

Run inside the Docker web container:

```bash
docker compose exec web bundle install
```

Expected: Sidekiq and letter_opener gems install successfully.

- [ ] **Step 6: Verify Sidekiq loads**

```bash
docker compose exec web bundle exec sidekiq -C config/sidekiq.yml -e development &
```

Expected: Sidekiq starts and connects to Redis. You should see `Sidekiq 7.x.x starting` in the output. Kill it after verifying (`Ctrl+C` or `kill %1`).

- [ ] **Step 7: Commit**

```bash
git add Gemfile Gemfile.lock config/sidekiq.yml config/application.rb config/environments/development.rb
git commit -m "feat: add sidekiq and letter_opener for async email delivery"
```

---

### Task 2: Pdf::BaseGenerator — Reusable PDF Base Class

**Files:**
- Create: `app/services/pdf/base_generator.rb`

- [ ] **Step 1: Create the base generator**

Create `app/services/pdf/base_generator.rb`:

```ruby
# frozen_string_literal: true

module Pdf
  class BaseGenerator
    BRAND_COLOR  = '4F46E5'
    ACCENT_COLOR = '818CF8'
    MUTED_COLOR  = '6B7280'
    TEXT_COLOR    = '111827'
    LIGHT_BG     = 'F3F4F6'
    BORDER_COLOR = 'E5E7EB'
    WHITE        = 'FFFFFF'

    def initialize(options = {})
      @document = Prawn::Document.new(
        page_size: options.fetch(:page_size, 'A4'),
        margin: options.fetch(:margin, 40)
      )
    end

    def render
      build_content
      apply_footer
      @document.render
    end

    private

    def build_content
      raise NotImplementedError, "#{self.class} must implement #build_content"
    end

    def header(title, subtitle = nil)
      @document.fill_color BRAND_COLOR
      @document.fill_rectangle [0, @document.cursor + 8], @document.bounds.width, 4
      @document.move_down 16

      @document.fill_color MUTED_COLOR
      @document.font_size(9) do
        @document.text 'SHUTTLE OFFICE', character_spacing: 3, style: :bold
      end
      @document.move_down 8

      @document.fill_color TEXT_COLOR
      @document.font_size(22) do
        @document.text title, style: :bold
      end

      if subtitle
        @document.move_down 4
        @document.fill_color MUTED_COLOR
        @document.font_size(9) { @document.text subtitle }
      end

      @document.move_down 20
      reset_colors
    end

    def section(title)
      @document.fill_color BRAND_COLOR
      @document.font_size(8) do
        @document.text title.upcase, style: :bold, character_spacing: 2
      end
      @document.move_down 10
      reset_colors

      yield if block_given?

      @document.move_down 6
      divider
      @document.move_down 16
    end

    def info_row(label, value)
      y_position = @document.cursor
      @document.fill_color MUTED_COLOR
      @document.font_size(9) do
        @document.text_box label,
          at: [0, y_position],
          width: 160,
          height: 14
      end
      @document.fill_color TEXT_COLOR
      @document.font_size(10) do
        @document.text_box value.to_s,
          at: [160, y_position],
          width: @document.bounds.width - 160,
          height: 14,
          style: :bold
      end
      @document.move_down 18
    end

    def divider
      @document.stroke_color BORDER_COLOR
      @document.line_width 0.5
      @document.stroke_horizontal_rule
      @document.stroke_color '000000'
      @document.line_width 1
    end

    def apply_footer
      @document.repeat(:all) do
        @document.bounding_box([0, 28], width: @document.bounds.width, height: 20) do
          @document.fill_color MUTED_COLOR
          @document.font_size(7) do
            @document.text_box(
              "Generated #{Time.current.strftime('%B %d, %Y at %H:%M')} | Shuttle Office",
              at: [0, 12],
              width: @document.bounds.width - 60
            )
            @document.text_box(
              "Page #{@document.page_number}",
              at: [0, 12],
              width: @document.bounds.width,
              align: :right
            )
          end
          @document.fill_color TEXT_COLOR
        end
      end
    end

    def reset_colors
      @document.fill_color TEXT_COLOR
      @document.stroke_color '000000'
    end
  end
end
```

- [ ] **Step 2: Verify it loads in Rails console**

```bash
docker compose exec web bundle exec rails runner "
  gen = Pdf::BaseGenerator.new
  begin
    gen.render
  rescue NotImplementedError => e
    puts \"OK: #{e.message}\"
  end
"
```

Expected: `OK: Pdf::BaseGenerator must implement #build_content`

- [ ] **Step 3: Commit**

```bash
git add app/services/pdf/base_generator.rb
git commit -m "feat: add Pdf::BaseGenerator abstract base for PDF generation"
```

---

### Task 3: Pdf::ReservationGenerator — Ticket-Style PDF

**Files:**
- Create: `app/services/pdf/reservation_generator.rb`

- [ ] **Step 1: Create the reservation generator**

Create `app/services/pdf/reservation_generator.rb`:

```ruby
# frozen_string_literal: true

module Pdf
  class ReservationGenerator < BaseGenerator
    def initialize(reservation)
      super()
      @reservation = reservation
      @schedule    = reservation.schedule
      @bus         = @schedule.bus
      @company     = @bus.company
      @user        = reservation.user
    end

    private

    def build_content
      header('Reservation Confirmation', "##{@reservation.uid}")
      route_section
      passenger_section
      booking_section
      qr_placeholder
      boarding_notice
    end

    def route_section
      section('Route') do
        render_times
        render_route_names
        info_row 'Date', @schedule.date.strftime('%A, %B %d, %Y')
        info_row 'Bus', "#{@bus.number} — #{@bus.model}"
        info_row 'Company', @company.name
      end
    end

    def render_times
      y = @document.cursor
      @document.font_size(28) do
        @document.fill_color TEXT_COLOR
        @document.text_box format_time(@schedule.departure_time),
          at: [0, y], width: 100, style: :bold
        @document.fill_color MUTED_COLOR
        @document.text_box "\u2192",
          at: [110, y], width: 30, align: :center
        @document.fill_color TEXT_COLOR
        @document.text_box format_time(@schedule.arrival_time),
          at: [150, y], width: 100, style: :bold
      end
      @document.move_down 36
    end

    def render_route_names
      y = @document.cursor
      @document.font_size(11) do
        @document.fill_color TEXT_COLOR
        @document.text_box @schedule.start_point,
          at: [0, y], width: 200
        @document.fill_color MUTED_COLOR
        @document.text_box "\u2192",
          at: [200, y], width: 20, align: :center
        @document.fill_color TEXT_COLOR
        @document.text_box @company.name,
          at: [220, y], width: 200
      end
      @document.move_down 22
      reset_colors
    end

    def passenger_section
      section('Passenger') do
        info_row 'Name', "#{@user.first_name} #{@user.last_name}"
        info_row 'Email', @user.email
        info_row 'Company', @user.company&.name
      end
    end

    def booking_section
      section('Booking Details') do
        info_row 'Reservation ID', @reservation.uid
        info_row 'Seats Available', "#{@schedule.available_seats} / #{@bus.capacity}"
        info_row 'Booked At', @reservation.created_at.strftime('%B %d, %Y at %H:%M')
      end
    end

    def qr_placeholder
      y = @document.cursor
      @document.stroke_color BORDER_COLOR
      @document.dash(2)
      @document.stroke_rectangle [@document.bounds.width - 84, y], 80, 80
      @document.undash
      @document.fill_color MUTED_COLOR
      @document.font_size(7) do
        @document.text_box 'QR CODE',
          at: [@document.bounds.width - 84, y - 30],
          width: 80, align: :center, style: :bold
        @document.text_box '(coming soon)',
          at: [@document.bounds.width - 84, y - 42],
          width: 80, align: :center
      end
      reset_colors
      @document.move_down 20
    end

    def boarding_notice
      @document.move_down 10
      notice_y = @document.cursor
      @document.fill_color BRAND_COLOR
      @document.fill_rounded_rectangle [0, notice_y], @document.bounds.width, 36, 4
      @document.fill_color WHITE
      @document.font_size(10) do
        @document.text_box 'This is your boarding pass. Please present it to the driver.',
          at: [12, notice_y - 10],
          width: @document.bounds.width - 24,
          height: 16,
          style: :bold
      end
      reset_colors
    end

    def format_time(time)
      time.strftime('%H:%M')
    end
  end
end
```

- [ ] **Step 2: Generate a test PDF to verify output**

```bash
docker compose exec web bundle exec rails runner "
  reservation = Reservation.includes(:user, schedule: { bus: :company }).first
  if reservation.nil?
    puts 'No reservations found. Create one first.'
    exit
  end
  pdf_bytes = Pdf::ReservationGenerator.new(reservation).render
  path = Rails.root.join('tmp', 'test_reservation.pdf')
  File.open(path, 'wb') { |f| f.write(pdf_bytes) }
  puts \"PDF generated: #{path} (#{pdf_bytes.bytesize} bytes)\"
"
```

Expected: A PDF file at `tmp/test_reservation.pdf` with correct reservation details. Open it to verify the layout.

- [ ] **Step 3: Commit**

```bash
git add app/services/pdf/reservation_generator.rb
git commit -m "feat: add Pdf::ReservationGenerator with ticket-style boarding pass layout"
```

---

### Task 4: Mailer Layout, ReservationMailer & Email Templates

**Files:**
- Modify: `app/views/layouts/mailer.html.erb`
- Create: `app/mailers/reservation_mailer.rb`
- Create: `app/views/reservation_mailer/confirmation.html.erb`
- Create: `app/views/reservation_mailer/confirmation.text.erb`

- [ ] **Step 1: Update the mailer layout**

Replace the contents of `app/views/layouts/mailer.html.erb` with:

```erb
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <style>
      body { margin: 0; padding: 0; background-color: #F9FAFB; -webkit-font-smoothing: antialiased; }
      table { border-collapse: collapse; }
      img { border: 0; outline: none; text-decoration: none; }
    </style>
  </head>
  <body style="margin: 0; padding: 24px 0; background-color: #F9FAFB;">
    <%= yield %>
  </body>
</html>
```

- [ ] **Step 2: Create the ReservationMailer**

Create `app/mailers/reservation_mailer.rb`:

```ruby
# frozen_string_literal: true

class ReservationMailer < ApplicationMailer
  def confirmation(reservation, pdf_bytes)
    @reservation = reservation
    @user        = reservation.user
    @schedule    = reservation.schedule
    @bus         = @schedule.bus
    @company     = @bus.company

    attachments["reservation_#{reservation.uid}.pdf"] = {
      mime_type: 'application/pdf',
      content: pdf_bytes
    }

    mail(
      to: @user.email,
      subject: "Your Shuttle Reservation \u2014 #{@schedule.start_point} to #{@company.name} :#{reservation.uid}"
    )
  end
end
```

- [ ] **Step 3: Create the HTML email template**

Create `app/views/reservation_mailer/confirmation.html.erb`:

```erb
<div style="max-width: 600px; margin: 0 auto; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <%# Header %>
  <div style="background-color: #4F46E5; padding: 24px 32px; border-radius: 8px 8px 0 0;">
    <p style="color: rgba(255,255,255,0.7); font-size: 10px; letter-spacing: 2px; text-transform: uppercase; margin: 0 0 8px;">
      Shuttle Office
    </p>
    <h1 style="color: #ffffff; font-size: 22px; font-weight: bold; margin: 0;">
      Reservation Confirmed
    </h1>
  </div>

  <%# Body %>
  <div style="background-color: #ffffff; padding: 32px; border: 1px solid #E5E7EB; border-top: none;">
    <p style="color: #111827; font-size: 15px; margin: 0 0 20px;">
      Hi <%= @user.first_name %>,
    </p>
    <p style="color: #6B7280; font-size: 14px; margin: 0 0 24px; line-height: 1.6;">
      Your shuttle reservation has been confirmed. Here are the details:
    </p>

    <%# Route card %>
    <div style="background-color: #F3F4F6; border-radius: 8px; padding: 20px; margin-bottom: 24px;">
      <table style="width: 100%;">
        <tr>
          <td style="font-size: 24px; font-weight: bold; color: #111827; padding-bottom: 4px;">
            <%= @schedule.departure_time.strftime('%H:%M') %>
          </td>
          <td style="font-size: 18px; color: #6B7280; padding: 0 8px 4px; text-align: center;">
            &rarr;
          </td>
          <td style="font-size: 24px; font-weight: bold; color: #111827; padding-bottom: 4px;">
            <%= @schedule.arrival_time.strftime('%H:%M') %>
          </td>
        </tr>
        <tr>
          <td colspan="3" style="padding-top: 8px;">
            <span style="color: #111827; font-size: 14px; font-weight: 600;">
              <%= @schedule.start_point %>
            </span>
            <span style="color: #6B7280; font-size: 14px;">&nbsp;&rarr;&nbsp;</span>
            <span style="color: #111827; font-size: 14px; font-weight: 600;">
              <%= @company.name %>
            </span>
          </td>
        </tr>
        <tr>
          <td colspan="3" style="padding-top: 8px; color: #6B7280; font-size: 13px;">
            <%= @schedule.date.strftime('%A, %B %d, %Y') %> &middot; Bus <%= @bus.number %>
          </td>
        </tr>
      </table>
    </div>

    <%# Attachment callout %>
    <div style="background-color: #EEF2FF; border-left: 3px solid #4F46E5; padding: 12px 16px; border-radius: 0 4px 4px 0; margin-bottom: 24px;">
      <p style="margin: 0; color: #4338CA; font-size: 13px; font-weight: 600;">
        Your PDF boarding pass is attached to this email.
      </p>
    </div>

    <p style="color: #6B7280; font-size: 13px; line-height: 1.6; margin: 0;">
      Please present your boarding pass to the driver when boarding.
      If you need to cancel, visit your dashboard.
    </p>
  </div>

  <%# Footer %>
  <div style="padding: 20px 32px; text-align: center; border-radius: 0 0 8px 8px;">
    <p style="color: #9CA3AF; font-size: 11px; margin: 0;">
      Shuttle Office &mdash; Office commuting infrastructure for modern teams.
    </p>
  </div>
</div>
```

- [ ] **Step 4: Create the text email template**

Create `app/views/reservation_mailer/confirmation.text.erb`:

```erb
Hi <%= @user.first_name %>,

Your shuttle reservation has been confirmed!

ROUTE DETAILS
------------------------------
<%= @schedule.departure_time.strftime('%H:%M') %> -> <%= @schedule.arrival_time.strftime('%H:%M') %>
<%= @schedule.start_point %> -> <%= @company.name %>
Date: <%= @schedule.date.strftime('%A, %B %d, %Y') %>
Bus: <%= @bus.number %>

PASSENGER
------------------------------
Name: <%= @user.first_name %> <%= @user.last_name %>
Email: <%= @user.email %>

BOOKING
------------------------------
Reservation ID: <%= @reservation.uid %>
Booked: <%= @reservation.created_at.strftime('%B %d, %Y at %H:%M') %>

Your PDF boarding pass is attached to this email.
Please present it to the driver when boarding.

--
Shuttle Office
Office commuting infrastructure for modern teams.
```

- [ ] **Step 5: Verify mailer renders in console**

```bash
docker compose exec web bundle exec rails runner "
  reservation = Reservation.includes(:user, schedule: { bus: :company }).first
  if reservation.nil?
    puts 'No reservations found.'
    exit
  end
  pdf_bytes = Pdf::ReservationGenerator.new(reservation).render
  mail = ReservationMailer.confirmation(reservation, pdf_bytes)
  puts \"To: #{mail.to}\"
  puts \"Subject: #{mail.subject}\"
  puts \"Attachments: #{mail.attachments.map(&:filename)}\"
  puts \"HTML body length: #{mail.html_part&.body&.to_s&.length || 0}\"
  puts \"Text body length: #{mail.text_part&.body&.to_s&.length || 0}\"
"
```

Expected: Shows the recipient email, subject line with route, one PDF attachment, and non-zero body lengths for both HTML and text parts.

- [ ] **Step 6: Commit**

```bash
git add app/views/layouts/mailer.html.erb app/mailers/reservation_mailer.rb app/views/reservation_mailer/
git commit -m "feat: add ReservationMailer with HTML and text templates"
```

---

### Task 5: ReservationConfirmationJob

**Files:**
- Create: `app/jobs/reservation_confirmation_job.rb`

- [ ] **Step 1: Create the background job**

Create `app/jobs/reservation_confirmation_job.rb`:

```ruby
# frozen_string_literal: true

class ReservationConfirmationJob < ApplicationJob
  queue_as :mailers

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(reservation_id)
    reservation = Reservation
      .includes(:user, schedule: { bus: :company })
      .find(reservation_id)

    return if reservation.user.email.blank?

    pdf_bytes = Pdf::ReservationGenerator.new(reservation).render
    ReservationMailer.confirmation(reservation, pdf_bytes).deliver_now
  end
end
```

- [ ] **Step 2: Verify job can be instantiated**

```bash
docker compose exec web bundle exec rails runner "
  puts ReservationConfirmationJob.queue_name
"
```

Expected: `mailers`

- [ ] **Step 3: Commit**

```bash
git add app/jobs/reservation_confirmation_job.rb
git commit -m "feat: add ReservationConfirmationJob for async email delivery"
```

---

### Task 6: Wire Up — Clean Model & Enqueue from Service

**Files:**
- Modify: `app/models/reservation.rb`
- Modify: `app/services/reservation_service/create.rb`

- [ ] **Step 1: Remove the old PDF callback from the model**

In `app/models/reservation.rb`, remove the `after_create :generate_reservation_pdf` line (line 12) and the entire `generate_reservation_pdf` method (lines 14-31). The file should become:

```ruby
# frozen_string_literal: true

class Reservation < ApplicationRecord
  include UidGenerator

  belongs_to :user, inverse_of: :reservations
  belongs_to :schedule, inverse_of: :reservations

  validates :schedule_id, :user_id, presence: true
  validates :schedule_id, uniqueness: { scope: :user_id, message: 'is already booked' }
end
```

- [ ] **Step 2: Enqueue the job from the create service**

In `app/services/reservation_service/create.rb`, modify the `call` method to enqueue the job after a successful transaction. Change:

```ruby
    def call
      result = ActiveRecord::Base.transaction do
        find_and_lock_schedule && check_availability && create_reservation &&
          decrement_seats && set_data && set_response
      end
      result || set_response
    end
```

To:

```ruby
    def call
      result = ActiveRecord::Base.transaction do
        find_and_lock_schedule && check_availability && create_reservation &&
          decrement_seats && set_data && set_response
      end
      schedule_confirmation_email if reservation&.persisted?
      result || set_response
    end
```

Then add a new private method after the existing `decrement_seats` method:

```ruby
    def schedule_confirmation_email
      ReservationConfirmationJob.perform_later(reservation.id)
    end
```

- [ ] **Step 3: Verify the wiring in console**

```bash
docker compose exec web bundle exec rails runner "
  puts 'Reservation model methods:'
  puts Reservation.instance_methods(false).sort.join(', ')
  puts ''
  puts 'Should NOT include generate_reservation_pdf:'
  puts Reservation.instance_methods(false).include?(:generate_reservation_pdf) ? 'FAIL - still there' : 'OK - removed'
"
```

Expected: `OK - removed`

- [ ] **Step 4: Commit**

```bash
git add app/models/reservation.rb app/services/reservation_service/create.rb
git commit -m "feat: wire reservation confirmation job into create service, remove model callback"
```

---

### Task 7: End-to-End Smoke Test

**Files:** None — verification only.

- [ ] **Step 1: Restart all services to pick up changes**

```bash
docker compose restart web sidekiq
```

Wait for both containers to be healthy.

- [ ] **Step 2: Check Sidekiq is processing the mailers queue**

```bash
docker compose logs sidekiq --tail=10
```

Expected: Sidekiq startup log showing it is listening on the `default` and `mailers` queues.

- [ ] **Step 3: Create a reservation via curl to trigger the full flow**

First, get a valid token by logging in:

```bash
curl -s -c - http://localhost:3000/api/v1/login \
  -H 'Content-Type: application/json' \
  -d '{"user": {"email": "user@example.com", "password": "password"}}' | head -5
```

Then create a reservation (replace TOKEN and SCHEDULE_ID with real values):

```bash
curl -X POST http://localhost:3000/api/v1/reservations \
  -H 'Content-Type: application/json' \
  -H 'Cookie: token=TOKEN_FROM_ABOVE' \
  -d '{"reservation": {"schedule_id": SCHEDULE_ID}}'
```

Expected: 201 Created response with reservation data.

- [ ] **Step 4: Verify the job executed**

```bash
docker compose logs sidekiq --tail=20
```

Expected: Log lines showing `ReservationConfirmationJob` performed successfully.

- [ ] **Step 5: Verify email was "sent" via Letter Opener**

In development, Letter Opener saves emails to `tmp/letter_opener/`. Check:

```bash
docker compose exec web ls -la tmp/letter_opener/
```

Expected: A directory with the email HTML file. Open it in a browser to see the full email with the PDF attachment link.

- [ ] **Step 6: Verify the PDF attachment**

Open the Letter Opener HTML file in a browser. Click the PDF attachment link. Verify:
- Header shows "SHUTTLE OFFICE" and "Reservation Confirmation"
- Route section shows correct times, start point, and company
- Passenger section shows correct user details
- Booking details section shows reservation UID
- QR placeholder box is present
- Boarding notice bar at the bottom
- Footer shows generation timestamp and page number

- [ ] **Step 7: Final commit (if any adjustments were needed)**

```bash
git add -A
git commit -m "chore: finalize reservation confirmation email feature"
```

# Reservation Confirmation Email with PDF Attachment

## Overview

When a user successfully creates a reservation, a background job generates a professional PDF boarding pass and emails it to the user. The PDF system uses a reusable base generator that other PDF types can extend.

## Architecture

```bash
ReservationService::Create (existing)
  └─ enqueues ReservationConfirmationJob(reservation.id)
       ├─ Pdf::ReservationGenerator.new(reservation).render  → raw PDF bytes
       └─ ReservationMailer.confirmation(reservation, pdf_bytes).deliver_now
```

**Principles:** SOLID throughout. Single Responsibility per class. Open/Closed via BaseGenerator inheritance. Dependency Inversion — job depends on generator/mailer interfaces, not internals.

## Components

### 1. Pdf::BaseGenerator (Abstract Base)

**File:** `app/services/pdf/base_generator.rb`

**Responsibility:** Common PDF structure, branding, and layout helpers for all PDF documents.

**Interface:**
- `initialize(options = {})` — accepts page_size, orientation overrides
- `render` → raw PDF bytes (String). Calls `build_content` then returns `@document.render`
- `build_content` — abstract, subclasses implement

**Layout helpers available to subclasses:**
- `header(title, subtitle = nil)` — "SHUTTLE OFFICE" brand name + accent bar + document title + optional subtitle
- `footer` — page number, generation timestamp, disclaimer
- `section(title, &block)` — bordered rounded box with tinted header strip, yields for content
- `info_row(label, value)` — two-column key/value with label left-aligned (muted) and value right-aligned (bold)
- `divider` — subtle horizontal rule

**Constants:**
- `BRAND_COLOR = "4F46E5"` (indigo-600, matching frontend brand-600)
- `MUTED_COLOR = "6B7280"` (gray-500)
- `TEXT_COLOR = "111827"` (gray-900)
- Page: A4, 40pt margins

### 2. Pdf::ReservationGenerator

**File:** `app/services/pdf/reservation_generator.rb`

**Responsibility:** Builds reservation-specific PDF content. Produces a professional ticket/boarding-pass style document.

**Interface:**
- `initialize(reservation)` — accepts a Reservation record (with associations loaded)
- Inherits `render` from BaseGenerator

**PDF layout (top to bottom):**
1. **Header** — "Reservation Confirmation" title, reservation UID as subtitle
2. **Route section** — bordered box containing:
   - Large departure_time → arrival_time visualization with arrow
   - Start point and destination (company name) below the times
   - Date prominently displayed
   - Bus number badge and company name
3. **Passenger section** — user full name, email, company name
4. **Booking details section** — reservation UID, seat availability (available/capacity), booking timestamp
5. **QR placeholder** — 80x80pt reserved box at bottom-right (future: encode reservation UID as QR code)
6. **Footer** — "This is your boarding pass. Please present it to the driver." + generation timestamp

### 3. ReservationMailer

**File:** `app/mailers/reservation_mailer.rb`

**Responsibility:** Compose and send reservation confirmation emails.

**Method:** `confirmation(reservation, pdf_bytes)`
- **To:** `reservation.user.email`
- **Subject:** `"Your Shuttle Reservation — #{start_point} to #{company_name} :#{reservation.uid}"`
- **Attachment:** PDF bytes as `reservation_#{reservation.uid}.pdf`, mime type `application/pdf`
- **HTML template:** inline-styled email with greeting, route summary, "boarding pass attached" callout, footer
- **Text template:** plain text fallback with same information

### 4. ReservationConfirmationJob

**File:** `app/jobs/reservation_confirmation_job.rb`

**Responsibility:** Orchestrate PDF generation and email delivery asynchronously.

**Queue:** `mailers`

**Behavior:**
- Accepts `reservation_id` (integer — Sidekiq best practice: serialize IDs, not objects)
- Loads reservation with eager-loaded associations: `user`, `schedule`, `schedule.bus`, `schedule.bus.company`
- Returns early (no error) if reservation no longer exists (user may have cancelled)
- Generates PDF via `Pdf::ReservationGenerator.new(reservation).render`
- Sends email via `ReservationMailer.confirmation(reservation, pdf_bytes).deliver_now`
- Retries: 3 attempts with default Active Job exponential backoff
- Discards on `ActiveRecord::RecordNotFound`

### 5. Email Templates

**HTML template:** `app/views/reservation_mailer/confirmation.html.erb`
- All styles inline (email client compatibility)
- Centered card layout, max-width 600px
- Brand color accent header
- Greeting: "Hi #{first_name},"
- Route summary card: start_point → company_name, times, date, bus number
- Callout box: "Your PDF boarding pass is attached to this email."
- Footer: "Shuttle Office — Office commuting infrastructure for modern teams."

**Text template:** `app/views/reservation_mailer/confirmation.text.erb`
- Plain text with same information, formatted with dashes and spacing

**Mailer layout:** `app/views/layouts/mailer.html.erb`
- Updated with proper HTML5 doctype, viewport meta, base email reset styles

### 6. Configuration Changes

**Gemfile additions:**
- `gem 'sidekiq', '~> 7.0'` — background job processing
- `gem 'letter_opener', group: :development` — opens emails in browser during dev

**`config/application.rb`:**
- `config.active_job.queue_adapter = :sidekiq`

**`config/environments/development.rb`:**
- `config.action_mailer.delivery_method = :letter_opener`
- `config.action_mailer.perform_deliveries = true`

**`config/sidekiq.yml`:**
```yaml
:concurrency: 5
:queues:
  - default
  - mailers
```

### 7. Model/Service Changes

**`app/models/reservation.rb`:**
- Remove `after_create :generate_reservation_pdf` callback
- Remove `generate_reservation_pdf` method
- Model becomes clean: just associations + validations

**`app/services/reservation_service/create.rb`:**
- After `set_data`, enqueue: `ReservationConfirmationJob.perform_later(reservation.id)`
- Job is enqueued outside the transaction (after successful commit)

## Data Flow

1. User hits `POST /api/v1/reservations` with `{ schedule_id: 123 }`
2. `ReservationService::Create` runs inside a transaction: finds schedule, checks availability, creates reservation, decrements seats
3. After successful transaction, enqueues `ReservationConfirmationJob.perform_later(reservation.id)`
4. Sidekiq picks up the job:
   a. Loads reservation with `includes(user: [], schedule: { bus: :company })`
   b. Calls `Pdf::ReservationGenerator.new(reservation).render` → PDF bytes
   c. Calls `ReservationMailer.confirmation(reservation, pdf_bytes).deliver_now`
5. In development: Letter Opener intercepts and opens email in browser with PDF attachment
6. In production: email goes via configured SMTP

## File Inventory

| File | Action | Purpose |
|------|--------|---------|
| `Gemfile` | Modify | Add sidekiq, letter_opener |
| `config/application.rb` | Modify | Set queue adapter to :sidekiq |
| `config/environments/development.rb` | Modify | Letter opener delivery method |
| `config/sidekiq.yml` | Create | Queue configuration |
| `app/services/pdf/base_generator.rb` | Create | Reusable PDF base class |
| `app/services/pdf/reservation_generator.rb` | Create | Reservation PDF builder |
| `app/mailers/reservation_mailer.rb` | Create | Email composition |
| `app/views/reservation_mailer/confirmation.html.erb` | Create | HTML email template |
| `app/views/reservation_mailer/confirmation.text.erb` | Create | Text email fallback |
| `app/views/layouts/mailer.html.erb` | Modify | Proper styled layout |
| `app/jobs/reservation_confirmation_job.rb` | Create | Async orchestration |
| `app/models/reservation.rb` | Modify | Remove old PDF callback |
| `app/services/reservation_service/create.rb` | Modify | Enqueue job after success |

## Error Handling

- **Job fails (PDF generation error):** Active Job retries 3 times with backoff. If all fail, job goes to Sidekiq dead set for manual inspection.
- **Reservation deleted before job runs:** Job loads reservation, gets nil, returns early. No error raised.
- **User has no email:** Mailer skips delivery if `reservation.user.email.blank?`.
- **PDF generation exception:** Caught by job retry mechanism. Logged via Rails logger.

## Future Extensions

- **Event-driven (Phase 2):** Wrap the job enqueue in an `ActiveSupport::Notifications` event subscriber. Other subscribers can react to `reservation.created` independently.
- **QR code:** Add `rqrcode` gem, encode reservation UID in the placeholder box.
- **Other PDF types:** Subclass `Pdf::BaseGenerator` — e.g., `Pdf::InvoiceGenerator`, `Pdf::ManifestGenerator`. Same header/footer/branding, different content.

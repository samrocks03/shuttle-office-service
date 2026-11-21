# Paid Rides with Hyperswitch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Employees pay a distance-based fare (BEST slabs) for each shuttle ride through a self-hosted Hyperswitch, with cities, stops and road distances configurable as data.

**Architecture:** New tables (cities, stops, stop_distances, fare tables, payments) plus nullable columns on existing ones. Three swappable interfaces chosen by data: `Distances::Provider` (OSRM), `Fares::Policy` (slab), `Payments::Gateway` (Hyperswitch). Paid booking runs only when the bus's company's city has `payments_enabled`; free booking keeps today's flow.

**Tech Stack:** Rails 7.0 API (Ruby 3.2.2), Postgres, Sidekiq, CanCanCan, jsonapi-serializer, RSpec + FactoryBot (+ WebMock, added here); Next.js 16 frontend with TanStack Query and shadcn; Hyperswitch `2026.09.30.0-hotfix2` from `../hyperswitch-lab`; OSRM public server.

**Spec:** `docs/superpowers/specs/2026-11-21-paid-rides-hyperswitch-design.md`

## Global Constraints

- Money is an integer in the smallest unit (`*_minor`, paise or cents). Never floats.
- New behaviour only when `cities.payments_enabled` is true for the bus's company's city. With it false, booking and cancel behave as today (except the access fix in Task 1).
- No existing column changes meaning. The only changed constraint is the reservations `(schedule_id, user_id)` unique index (Task 9).
- No distance or geocoding call during a booking. Distances are read from `stop_distances`.
- Effective km = `override_km` if present, else `computed_km`. Recompute never writes `override_km`.
- Fare snapshot is stored on the reservation at hold time and never recomputed.
- A paid reservation is confirmed only by `Payments::ApplyStatus` (webhook or sync). Boarding-pass email is queued only on `confirmed`.
- Hold time: 10 minutes (`Reservation::HOLD_DURATION = 10.minutes`).
- Raw card data never reaches Rails or the Next.js server; only the Hyperswitch iframe sees it.
- Secrets come from ENV (`HYPERSWITCH_URL`, `HYPERSWITCH_API_KEY`, `HYPERSWITCH_ADMIN_API_KEY`, `HYPERSWITCH_PROFILE_ID`, `HYPERSWITCH_PUBLISHABLE_KEY`, `HYPERSWITCH_WEBHOOK_SECRET`, `OSRM_URL`). Never logged or printed.
- Service objects follow `app/services/<name>_service/<action>.rb` subclassing `Base`, returning `set_response`; new domain services may live in `app/services/<domain>/` modules (`Distances::`, `Fares::`, `Payments::`, `Reservations::`).
- Locale strings go in `config/locales/en.yml` under the existing key style (`reservation.<action>.failure.detail`).
- Commits: author must be `Samarth Kulkarni <svkulkarni23@gmail.com>`; no Claude trailers (user's global CLAUDE.md).
- Run specs with `bundle exec rspec <path>` from the repo root (local Ruby 3.2.2, test DB `officebusbooking_test`).

## Review Focus

1. **Webhook and sync arrive in any order, more than once.** A `payment_succeeded` webhook after the sync already confirmed, or after expiry, must not double-confirm, double-email or leave a paid ride unrefunded. Test owned by Task 12.
2. **Expiry racing a UPI payment still processing.** The expiry job must not free the seat while Hyperswitch says `processing`. Test owned by Task 14.
3. **A schedule with no price** (missing stops, unrouted pair, no active fare table on that date) must refuse a paid booking with a clear error, and still list (fare `null`) in the schedule API. Test owned by Task 7 and Task 10.
4. **Cancel after departure, or double cancel,** must be refused without a second refund. Test owned by Task 10.
5. **Distance exactly on a slab boundary and fractional km** (5.0 → Rs 10, 5.01 → Rs 15 Non-AC). Test owned by Task 6.

---

## Part A — Reservation access (spec "Reservation access", build step 0)

### Task 1: Owner-scoped reservations

**Files:**
- Modify: `app/controllers/application_controller.rb` (`current_user_params`)
- Modify: `app/services/reservation_service/{index,show,create,destroy}.rb`
- Modify: `app/services/repositories/reservation_repository.rb`
- Modify: `config/locales/en.yml`
- Test: `spec/requests/api/v1/reservations_access_spec.rb` (new); update `spec/requests/api/v1/reservations_spec.rb`, `spec/integration/api/v1/reservations_spec.rb` where they relied on the gap

**Interfaces:**
- Produces: `current_user_params` returns `{ user_id:, user_uid:, admin: Boolean, guest: Boolean }`. `ReservationRepository.scope_for(current_user) -> ActiveRecord::Relation` (all for admin, own for others). Every later reservation/payment service finds reservations through `scope_for`.

- [ ] **Step 1: Write the failing specs** in `reservations_access_spec.rb`:
  - `employee sees only own reservations in index` — two users each with one reservation; index for user A returns exactly A's uid.
  - `show of another user's reservation returns 404`.
  - `destroy of another user's reservation returns 404 and keeps it` — `Reservation.exists?(id)` stays true, seats unchanged.
  - `create ignores user_id from an employee` — POST with `user_id: other.id` creates a reservation whose `user_id == caller.id`.
  - `admin can show and destroy any reservation` — 200 for both.
  - `guest cannot create` — role guest, POST returns 403, `Reservation.count` unchanged.
- [ ] **Step 2: Run** `bundle exec rspec spec/requests/api/v1/reservations_access_spec.rb` — expect failures on all but admin.
- [ ] **Step 3: Implement.** `current_user_params` adds `admin: @current_user.admin?`, `guest: @current_user.guest?`. Index/Show/Destroy build their query from `ReservationRepository.scope_for(current_user)`; Show/Destroy add `reservation.not_found` error when absent (controller already maps to 404/422 — Destroy must map not found to 404: add `status: result.key == 'reservation.not_found' ? :not_found : :unprocessable_entity`). Create uses `params[:user_id]` only when `current_user[:admin]`. Create returns a `reservation.guest_forbidden` error mapped to 403 when `current_user[:guest]`. Locale: `reservation.guest_forbidden.detail: "Guests cannot book rides. Please sign in as an employee."`
- [ ] **Step 4: Run** the new spec and `bundle exec rspec spec/requests spec/integration` — all pass after updating specs that posted another user's `user_id`.
- [ ] **Step 5: Commit** `fix(reservations): scope reservations to their owner, block guest booking`.

---

## Part B — Cities, stops and distances (build step 1)

### Task 2: Cities, stops, distances schema

**Files:**
- Create: `db/migrate/20261121000001_create_cities.rb`, `..._create_stops.rb`, `..._create_stop_distances.rb`, `..._add_routing_columns.rb`
- Create: `app/models/city.rb`, `app/models/stop.rb`, `app/models/stop_distance.rb`
- Modify: `app/models/company.rb`, `app/models/bus.rb`, `app/models/schedule.rb`
- Create: `spec/factories/cities.rb`, `spec/factories/stops.rb`, `spec/factories/stop_distances.rb`
- Test: `spec/models/stop_distance_spec.rb`, `spec/models/schedule_spec.rb` (new)

**Interfaces:**
- Produces tables exactly as the spec "Data model" lists for `cities`, `stops`, `stop_distances`, plus `companies.city_id` (nullable FK), `buses.service_class` (string, default `"non_ac"`, inclusion in `Bus::SERVICE_CLASSES = %w[non_ac ac]`), `schedules.from_stop_id`, `schedules.to_stop_id` (nullable FKs to stops).
- `Stop::KINDS = %w[pickup office]`; scopes `Stop.pickups`, `Stop.offices`, `Stop.active`.
- `StopDistance#effective_km -> BigDecimal | nil`; `StopDistance.between(from_stop, to_stop) -> StopDistance | nil`.
- `Schedule#city -> City | nil` (via `bus.company.city`); `Schedule#stop_distance -> StopDistance | nil`.
- `stop_distances.computed_km`, `override_km`: `decimal(8,3)`; `computed_minutes`: integer. Unique index `(from_stop_id, to_stop_id)`. Check constraint `from_stop_id <> to_stop_id`.
- All new tables include `uid uuid default gen_random_uuid()` and `UidGenerator`, like existing tables.

- [ ] **Step 1: Write failing model specs:** `effective_km prefers override_km` (computed 18.4, override 17.0 → 17.0); `effective_km falls back to computed_km`; `between returns nil for unknown pair`; `schedule#stop_distance` finds the row for its from/to stops; `bus rejects service_class "luxury"`.
- [ ] **Step 2: Run** `bundle exec rspec spec/models` — fail (tables missing).
- [ ] **Step 3: Write migrations and models;** run `bin/rails db:migrate` and `RAILS_ENV=test bin/rails db:migrate`.
- [ ] **Step 4: Run** `bundle exec rspec spec/models spec/requests` — all pass; existing schedule/bus specs unaffected.
- [ ] **Step 5: Commit** `feat(routing): add cities, stops and stop distances`.

### Task 3: Distance providers

**Files:**
- Modify: `Gemfile` (test group: `gem 'webmock'`), `spec/rails_helper.rb` (`require 'webmock/rspec'`, allow localhost)
- Create: `app/services/distances/provider.rb`, `app/services/distances/registry.rb`, `app/services/distances/osrm.rb`, `app/services/distances/haversine.rb`
- Create: `spec/fixtures/osrm/table_2x2.json` (recorded shape of an OSRM `/table` response)
- Test: `spec/services/distances/osrm_spec.rb`, `spec/services/distances/haversine_spec.rb`

**Interfaces:**
- Produces: `Distances::Provider#matrix(sources: Array<Stop>, destinations: Array<Stop>) -> Array<Array<Distances::Cell>>`, `Distances::Cell = Struct.new(:km, :minutes)` (both `nil` when no route). `Distances::Registry.fetch(name) -> Provider instance` with `"osrm"` and `"haversine"` registered; unknown name raises `Distances::UnknownProvider`.
- `Distances::Osrm.new(base_url: ENV.fetch('OSRM_URL', 'https://router.project-osrm.org'), max_coordinates: 100)`. Request: `GET {base}/table/v1/driving/{lng,lat;...}?sources=0;1&destinations=2;3&annotations=distance,duration`. Coordinates are `longitude,latitude`. Metres → km rounded to 3 places; seconds → minutes rounded up. Batches so `sources + destinations <= max_coordinates` per request. Non-`"Ok"` code raises `Distances::ProviderError`.
- `Distances::Haversine` returns great-circle km × 1.4, minutes `nil`.

- [ ] **Step 1: Write failing specs:** Osrm builds the URL with lng first and correct source/destination indexes (WebMock `a_request(...).with(query: hash_including(...))`); parses fixture into `[[Cell(12.345, 21), ...]]`; `null` distance in response → `Cell(nil, nil)`; 3 sources × 3 destinations with `max_coordinates: 4` makes multiple requests and stitches one 3×3 matrix; `{"code":"NoRoute"}` → raises. Haversine: Pune Station (18.5286, 73.8743) to Hinjewadi Phase 1 (18.5913, 73.7389) ≈ 22.2 km ±0.5 after ×1.4.
- [ ] **Step 2: Run** `bundle exec rspec spec/services/distances` — fail.
- [ ] **Step 3: Implement** with `Net::HTTP` (no new HTTP gem). Registry is a frozen hash `{ 'osrm' => Osrm, 'haversine' => Haversine }`.
- [ ] **Step 4: Run** — pass.
- [ ] **Step 5: Commit** `feat(distances): add OSRM and haversine distance providers`.

### Task 4: Compute distances for a city

**Files:**
- Create: `app/services/distances/compute_for_city.rb`, `app/jobs/compute_city_distances_job.rb`, `lib/tasks/stops.rake`
- Modify: `app/models/stop.rb` (`after_commit` enqueue on create, coordinate change, or `active` turned on)
- Test: `spec/services/distances/compute_for_city_spec.rb`, `spec/jobs/compute_city_distances_job_spec.rb`

**Interfaces:**
- Consumes: `Distances::Registry.fetch(city.distance_provider)`.
- Produces: `Distances::ComputeForCity.new(city, provider: nil).call -> { pairs: Integer, unrouted: Integer }`. Upserts both directions (pickups→offices and offices→pickups) for active stops; sets `computed_km`, `computed_minutes`, `source`, `computed_at`; never writes override columns. Rake: `bin/rails "stops:compute_distances[pune]"` (city by name, case-insensitive) prints the returned counts.

- [ ] **Step 1: Write failing specs** with a fake provider returning fixed cells: 2 pickups + 1 office → 4 rows; second run updates `computed_km` and leaves an existing `override_km` (17.0) untouched; a `Cell(nil, nil)` row stored with `computed_km nil` and counted in `unrouted`; inactive stops excluded. Job spec: creating a stop enqueues `ComputeCityDistancesJob` with the city id.
- [ ] **Step 2: Run** — fail.
- [ ] **Step 3: Implement;** use `StopDistance.upsert_all(..., unique_by: %i[from_stop_id to_stop_id], update_only: %i[computed_km computed_minutes source computed_at])`.
- [ ] **Step 4: Run** — pass.
- [ ] **Step 5: Commit** `feat(distances): compute and store distances for every stop pair`.

### Task 5: Pune seed

**Files:**
- Create: `db/seeds/cities/pune.yml`, `app/services/cities/load_seed.rb`, `lib/tasks/cities.rake`
- Test: `spec/services/cities/load_seed_spec.rb`

**Interfaces:**
- Produces: `Cities::LoadSeed.new(path).call -> City` (idempotent: finds city by name, upserts stops by `(city_id, name)`). YAML shape:

```yaml
city: { name: Pune, country_code: IN, currency: INR, time_zone: Asia/Kolkata, distance_provider: osrm, payments_enabled: false }
stops:
  - { name: Wakad, kind: pickup, latitude: 18.59, longitude: 73.76, osm_ref: "node/123" }
fares: []   # filled in Task 7
```

- Rake: `bin/rails "cities:load[pune]"` loads `db/seeds/cities/pune.yml`, then runs `ComputeForCity`.

- [ ] **Step 1: Build the YAML.** Pickups: Wakad, Baner, Aundh, Kothrud, Hadapsar, Viman Nagar, Pimple Saudagar, Shivaji Nagar, Kharadi, Magarpatta Gate, Swargate, Pune Railway Station. Offices: Hinjewadi Phase 1, Hinjewadi Phase 2, Hinjewadi Phase 3, EON IT Park Kharadi, Magarpatta City, Commerzone Yerawada. Look up each with Nominatim (`https://nominatim.openstreetmap.org/search?format=jsonv2&q=<name>, Pune&limit=1`, generic User-Agent, 1 request per second), check each result lies inside lat 18.40–18.70, lng 73.70–74.00, and record `osm_ref` (`<osm_type>/<osm_id>`). Do not geocode from memory.
- [ ] **Step 2: Write failing spec:** loading the file twice gives one city and 18 stops; every stop has coordinates inside the Pune box; 12 pickups and 6 offices.
- [ ] **Step 3: Run** — fail. **Step 4: Implement** `LoadSeed` and the rake task. **Step 5: Run** — pass.
- [ ] **Step 6: Run against dev** `bin/rails "cities:load[pune]"` — expect `pairs: 144` (12×6×2) and report `unrouted`. Spot-check 3 pairs against a map; record the check in the PR body.
- [ ] **Step 7: Commit** `feat(cities): seed Pune stops and compute distances`.

---

## Part C — Fares (build step 2)

### Task 6: Fare tables and slab policy

**Files:**
- Create: migration `..._create_fare_tables.rb` (tables `fare_tables`, `fare_slabs`), `app/models/fare_table.rb`, `app/models/fare_slab.rb`, `app/services/fares/policy.rb`, `app/services/fares/registry.rb`, `app/services/fares/slab_policy.rb`, `app/services/fares/quote.rb`
- Create: `spec/factories/fare_tables.rb` (trait `:best_non_ac`, `:best_ac` with the spec's Pune slabs)
- Test: `spec/services/fares/slab_policy_spec.rb`

**Interfaces:**
- Produces: `fare_tables(city_id, service_class, currency, policy default "slab", effective_from date, active bool, step_km decimal, step_amount_minor int)`; `fare_slabs(fare_table_id, up_to_km decimal(8,3), amount_minor int)`, unique `(fare_table_id, up_to_km)`. `FareTable.active_on(city, service_class, date) -> FareTable | nil` (latest `effective_from <= date`, active). To change prices, add a new table with a later `effective_from`; the read-only guard for tables already used by bookings is added in Task 9, where `reservations.fare_table_id` is created.
- `Fares::Quote = Struct.new(:amount_minor, :currency, :distance_km, :slab_label, :fare_table_id, keyword_init: true)`; `#to_h`.
- `Fares::SlabPolicy#price(distance_km:, fare_table:) -> Fares::Quote`. First slab with `distance_km <= up_to_km`; beyond last slab add `step_amount_minor * ceil((distance_km - last_up_to) / step_km)`. `slab_label` like `"up to 20 km"` or `"55 km slab"`.
- `Fares::Registry.fetch("slab") -> SlabPolicy`.

- [ ] **Step 1: Write failing spec** with these exact Non-AC / AC expectations (amounts in paise): 0.1 → 1000/1200; 5.0 → 1000/1200; 5.01 → 1500/2000; 10 → 1500/2000; 15 → 2000/3000; 20 → 3000/3500; 20.5 → 3500/4000; 50 → 6000/6500; 50.01 → 6500/7000; 73 → 8500/9000 (6000/6500 + ceil(23/5)=5 steps × 500). Also `distance_km` 0 or negative raises `ArgumentError`.
- [ ] **Step 2: Run** — fail. **Step 3: Implement.** **Step 4: Run** — pass.
- [ ] **Step 5: Commit** `feat(fares): add versioned fare tables and BEST slab policy`.

### Task 7: Quote a schedule

**Files:**
- Create: `app/services/fares/quote_for_schedule.rb`
- Modify: `db/seeds/cities/pune.yml` (`fares:` section: `non_ac` and `ac` tables, `effective_from: 2026-12-01`, step 5 km / 500), `app/services/cities/load_seed.rb` (load fares), `app/serializers/v1/schedule_serializer.rb` (attribute `fare`), `app/serializers/v1/bus_serializer.rb` (`service_class`), schedule and bus create/update services and their permitted params (`from_stop_id`/`to_stop_id` as stop uids, `service_class`)
- Test: `spec/services/fares/quote_for_schedule_spec.rb`, `spec/requests/api/v1/schedules_spec.rb` (add cases)

**Interfaces:**
- Produces: `Fares::QuoteForSchedule.new(schedule).call -> Fares::Quote | nil` plus `#reason -> Symbol | nil` (`:no_city`, `:no_stops`, `:no_distance`, `:no_fare_table`). Schedule JSON gets `fare: { amount_minor, currency, distance_km, slab_label } | null` and `fare_unavailable_reason`.

- [ ] **Step 1: Write failing specs:** priced schedule (AC bus, 18.4 km) → `amount_minor 3500`, currency INR; uses `override_km` when set; each reason returned for each missing piece; schedule index JSON includes `fare.amount_minor` and a schedule without stops lists with `fare: nil`.
- [ ] **Step 2: Run** — fail. **Step 3: Implement.** **Step 4: Run** `bundle exec rspec spec/services/fares spec/requests/api/v1/schedules_spec.rb` — pass.
- [ ] **Step 5: Commit** `feat(fares): show the fare on schedules`.

### Task 8: Fare in the frontend

**Files:**
- Modify: `frontend/src/features/schedules/(types)/*` (add `fare` type), schedule card and schedule page components under `frontend/src/features/schedules/(components)/`
- Create: `frontend/src/shared/lib/money.ts` (`formatMoney(amountMinor: number, currency: string): string` — `"Rs 35"` for INR whole rupees, `Intl.NumberFormat` otherwise)

- [ ] **Step 1:** Add `formatMoney` with a unit test if the frontend has a test runner; otherwise verify by type-check.
- [ ] **Step 2:** Show a fare badge `Rs 35 · AC · 18.4 km` on schedule cards and the schedule page; "Fare not set" when `fare` is null.
- [ ] **Step 3: Verify** `cd frontend && npm run lint && npx tsc --noEmit`; then open `/schedules` in the browser preview and screenshot a priced card.
- [ ] **Step 4: Commit** `feat(frontend): show ride fares on schedules`.

---

## Part D — Paid reservations (build step 3)

### Task 9: Reservation states and payment tables

**Files:**
- Create: migration `..._add_payment_state_to_reservations.rb` (columns per spec + `fare_table_id`; replace unique index with partial unique index `WHERE status IN ('pending_payment','confirmed')`), migration `..._create_payments_refunds_webhook_events.rb`
- Create: `app/models/payment.rb`, `app/models/refund.rb`, `app/models/payment_webhook_event.rb`, `app/services/reservations/transition.rb`
- Modify: `app/models/reservation.rb` (status enum with string values, default `"confirmed"`; drop the model `uniqueness` validation in favour of the partial index with a scoped validation over active statuses), `app/models/fare_table.rb` (`before_update` and `before_destroy` raise `ActiveRecord::ReadOnlyRecord` when `Reservation.exists?(fare_table_id: id)`)
- Test: `spec/services/reservations/transition_spec.rb`, `spec/models/reservation_spec.rb`

**Interfaces:**
- Produces: `Reservation.statuses = { confirmed:, pending_payment:, cancelled:, expired: }` (string-backed), `Reservation::HOLD_DURATION`, `Reservation#open_payments`, `Reservation#succeeded_payment`.
- `Payment(reservation_id, gateway, gateway_payment_id unique, status, amount_minor, currency, connector, last_error, raw jsonb)`; `Payment::OPEN = %w[requires_payment_method requires_confirmation requires_customer_action processing]`; `Payment#succeeded?`.
- `Refund(payment_id, gateway_refund_id unique, amount_minor, status default "pending", reason)`.
- `PaymentWebhookEvent(gateway, event_id unique, event_type, gateway_payment_id, received_at)`.
- `Reservations::Transition.call(reservation, to:, reason:) -> true | false` with allowed moves exactly as the spec table (`pending_payment→confirmed|expired|cancelled`, `confirmed→cancelled`). Uses `reservation.with_lock`; returns false for any other move (including same-state); sets `cancelled_at` on cancel; queues `ReservationConfirmationJob` on `→confirmed`; on `→expired|cancelled` calls `schedule.increment_available_seat!`.

- [ ] **Step 1: Write failing specs:** each allowed move succeeds; `confirmed→expired`, `expired→confirmed`, `cancelled→cancelled` return false and change nothing; confirm enqueues the email job exactly once; expire gives the seat back; re-booking the same schedule after `expired` succeeds; two active bookings for the same user+schedule are rejected; existing reservations default to `confirmed`; updating a fare table used by a reservation raises `ActiveRecord::ReadOnlyRecord`.
- [ ] **Step 2: Run** — fail. **Step 3: Implement + migrate.** **Step 4: Run** `bundle exec rspec` (whole suite) — pass.
- [ ] **Step 5: Commit** `feat(reservations): add payment states and payment records`.

### Task 10: Paid hold and cancel, behind a gateway interface

**Files:**
- Create: `app/services/payments/gateway.rb` (interface + `Payments::Gateway.current` returning the configured gateway; tests inject a fake), `app/services/payments/start.rb`, `spec/support/fake_gateway.rb`
- Modify: `app/services/reservation_service/create.rb`, `app/services/reservation_service/destroy.rb`, `app/serializers/v1/reservation_serializer.rb` (status, fare, `hold_expires_at`), `config/locales/en.yml`
- Test: `spec/requests/api/v1/paid_reservations_spec.rb`

**Interfaces:**
- Produces the gateway contract every later task implements or calls:

```ruby
# All amounts in minor units. Each method returns a Payments::Result
# (success?, data Hash, error String|nil). Never raises for API errors.
create_payment(amount_minor:, currency:, reference:, customer_email:, return_url:) # data: { id:, client_secret:, status: }
fetch_payment(id, sync: false)                                                    # data: { id:, status:, connector:, error: }
cancel_payment(id)
create_refund(payment_id:, amount_minor:, reason:)                                # data: { id:, status: }
fetch_refund(id)
verify_webhook(raw_body:, headers:) -> Boolean
```

- `Payments::Start.new(reservation).call -> Payments::Result` creates a gateway payment for the reservation's fare and stores a `Payment` row (used on hold and on retry).
- Create (paid path, chosen when `schedule.city&.payments_enabled`): quote via Task 7 (refuse with `reservation.not_priced` + reason if nil), lock schedule, take seat, save `pending_payment` with fare snapshot and `hold_expires_at`, then `Payments::Start`; if the gateway fails, transition to `expired` (seat back) and return `reservation.payment_start_failed`. Response adds `payment: { client_secret, publishable_key: ENV['HYPERSWITCH_PUBLISHABLE_KEY'] }`. No email here. Enqueue `ReservationHoldExpiryJob.set(wait_until: hold_expires_at)` (job class from Task 14; create an empty stub job here).
- Destroy (paid path): `pending_payment` → cancel open payments, transition `cancelled`. `confirmed` before departure (`schedule.date` + `departure_time` in the city's time zone is in the future) → transition `cancelled`, `create_refund` for the full succeeded amount, store `Refund`. After departure → `reservation.cancel_too_late`. Already cancelled/expired → `reservation.not_cancellable`. Paid reservations are never deleted.

- [ ] **Step 1: Write failing request specs** with `FakeGateway`: paid booking returns 201, status `pending_payment`, `fare.amount_minor 3500`, `payment.client_secret` present, seat taken, no email job; unpriced schedule → 422 with `not_priced`; gateway failure → 422 and seat back; cancel pending → `cancelled`, `cancel_payment` called, seat back; cancel confirmed before departure → refund created for 3500; cancel after departure → 422 and no refund; second cancel → 422 and still one refund; free company booking unchanged (status `confirmed`, email job enqueued).
- [ ] **Step 2: Run** — fail. **Step 3: Implement.** **Step 4: Run** `bundle exec rspec` — pass.
- [ ] **Step 5: Commit** `feat(reservations): paid hold and cancel with refunds`.

---

## Part E — Hyperswitch (build step 4)

### Task 11: Hyperswitch gateway client

**Files:**
- Create: `app/services/payments/hyperswitch.rb`, `spec/fixtures/hyperswitch/*.json` (payment create, payment get, refund create, refund get, error body)
- Test: `spec/services/payments/hyperswitch_spec.rb`

**Interfaces:**
- Consumes: the contract from Task 10.
- Produces: `Payments::Hyperswitch.new(base_url: ENV.fetch('HYPERSWITCH_URL'), api_key: ENV.fetch('HYPERSWITCH_API_KEY'), profile_id: ENV.fetch('HYPERSWITCH_PROFILE_ID'), webhook_secret: ENV.fetch('HYPERSWITCH_WEBHOOK_SECRET'))`. Calls, all with header `api-key`:
  - `POST /payments` with `amount, currency, confirm: false, capture_method: "automatic", profile_id, email, return_url, metadata: { reservation_uid: reference }`
  - `GET /payments/:id` (adds `?force_sync=true` when `sync: true`)
  - `POST /payments/:id/cancel` with `cancellation_reason`
  - `POST /refunds` with `payment_id, amount, reason`; `GET /refunds/:id`
  - `verify_webhook`: HMAC-SHA512 hex of the raw body with `webhook_secret`, compared in constant time to header `x-webhook-signature-512`.
- `Payments::Gateway.current` returns this class when `ENV['HYPERSWITCH_URL']` is set.

- [ ] **Step 1: Write failing specs** with WebMock: each call hits the right path, method, `api-key` header and body; `force_sync=true` only when asked; a 4xx body maps to `success? false` with the Hyperswitch `error.message`; timeout maps to `success? false`; signature good/bad/missing.
- [ ] **Step 2: Run** — fail. **Step 3: Implement** with `Net::HTTP`, 10 s open/read timeouts. **Step 4: Run** — pass.
- [ ] **Step 5: Commit** `feat(payments): add Hyperswitch gateway client`.

### Task 12: Webhook and status application

**Files:**
- Create: `app/services/payments/apply_status.rb`, `app/controllers/api/v1/webhooks_controller.rb`
- Modify: `config/routes.rb` (`post '/webhooks/hyperswitch', to: 'webhooks#hyperswitch'` inside `api/v1`)
- Test: `spec/services/payments/apply_status_spec.rb`, `spec/requests/api/v1/webhooks_spec.rb`

**Interfaces:**
- Produces: `Payments::ApplyStatus.new(payment, gateway_data).call -> Symbol` (`:confirmed`, `:refunded_late`, `:unchanged`, `:failed`). Updates `payment.status/connector/last_error`. On `succeeded`: if reservation `pending_payment` → `Transition to: :confirmed`; if reservation `expired|cancelled` → `create_refund` for the full amount and store `Refund` (`reason: "late_success"`) unless one exists. On refund events updates `Refund.status`. Used by the webhook (Task 12), the status endpoint (Task 13) and the jobs (Task 14).
- Webhook controller skips `authenticate`; reads the raw body; 401 if `verify_webhook` false; stores `PaymentWebhookEvent` (duplicate `event_id` → 200 and no work); finds `Payment` by `content.object.payment_id` (unknown → 200, logged); calls `ApplyStatus`.

- [ ] **Step 1: Write failing specs:** succeeded webhook confirms and enqueues one email; same event twice → one email; a second distinct succeeded event for an already-confirmed reservation → `:unchanged`, no second email; succeeded after `expired` → one refund (late_success), and a repeat does not add a second; bad signature → 401 and nothing stored; `refund_succeeded` sets refund status.
- [ ] **Step 2: Run** — fail. **Step 3: Implement.** **Step 4: Run** — pass.
- [ ] **Step 5: Commit** `feat(payments): handle Hyperswitch webhooks`.

### Task 13: Payment status and retry endpoints

**Files:**
- Modify: `config/routes.rb` (`get '/reservations/:id/payment'`, `post '/reservations/:id/payment'` inside `api/v1`), `app/controllers/api/v1/reservations_controller.rb`
- Create: `app/services/reservation_service/payment_status.rb`, `app/services/reservation_service/retry_payment.rb`
- Test: `spec/requests/api/v1/reservation_payments_spec.rb`

**Interfaces:**
- Consumes: `ReservationRepository.scope_for` (Task 1), `ApplyStatus` (Task 12), `Payments::Start` (Task 10).
- `GET` returns `{ status, payment_status, connector, hold_expires_at }`; when the reservation is `pending_payment` it first calls `fetch_payment(latest.id, sync: true)` and `ApplyStatus`.
- `POST` (retry) allowed only when `pending_payment`, before `hold_expires_at`, and the latest payment is `failed` or `cancelled`; returns a new `client_secret`. Otherwise 422 `reservation.retry_not_allowed`.

- [ ] **Step 1: Write failing specs:** pending + sync says succeeded → response `confirmed`; another user's reservation → 404; retry after a failed payment → new `Payment` row and new client secret, hold time unchanged; retry while latest is `processing` → 422; retry after hold expired → 422.
- [ ] **Step 2: Run** — fail. **Step 3: Implement.** **Step 4: Run** — pass.
- [ ] **Step 5: Commit** `feat(payments): payment status sync and retry`.

### Task 14: Hold expiry and refund sync jobs

**Files:**
- Modify: `app/jobs/reservation_hold_expiry_job.rb` (stub from Task 10)
- Create: `app/jobs/refund_sync_job.rb`, `config/sidekiq.yml` entry or `sidekiq-cron`-free self-rescheduling (Claude's call: self-rescheduling job, no new gem)
- Test: `spec/jobs/reservation_hold_expiry_job_spec.rb`, `spec/jobs/refund_sync_job_spec.rb`

**Interfaces:**
- `ReservationHoldExpiryJob.perform(reservation_id)`: no-op unless `pending_payment`. Syncs every open payment (`fetch_payment sync: true` + `ApplyStatus`). If now confirmed → done. If any payment is `processing` → re-enqueue itself in 2 minutes (at most 5 times, tracked by an argument), then expire anyway and rely on the late-success refund. Else cancel open payments and `Transition to: :expired`.
- `RefundSyncJob.perform`: for refunds `pending` older than 1 minute, `fetch_refund` and update status; re-enqueues itself every 10 minutes.

- [ ] **Step 1: Write failing specs:** payment succeeded at expiry time → reservation `confirmed`, seat still taken; payment `processing` → still `pending_payment`, job re-enqueued, seat still taken; payment failed → `expired`, seat back, payment cancel called; already confirmed → nothing changes; after 5 processing retries → `expired`. Refund sync: pending → succeeded.
- [ ] **Step 2: Run** — fail. **Step 3: Implement.** **Step 4: Run** `bundle exec rspec` — pass.
- [ ] **Step 5: Commit** `feat(payments): expire unpaid holds and sync refunds`.

### Task 15: Local Hyperswitch setup

**Files:**
- Create: `lib/tasks/payments.rake` (`payments:setup_hyperswitch`), `app/services/payments/hyperswitch_setup.rb`
- Modify: `compose.yaml` (`extra_hosts: ["host.docker.internal:host-gateway"]` on `web` and `sidekiq`; pass the `HYPERSWITCH_*` and `OSRM_URL` env vars), `.env.sample` (names only)
- Modify (lab, outside this repo): `../hyperswitch-lab/compose.override.yml` Postgres port `5433:5432` → `5435:5432`; `../hyperswitch-lab/lab.sh` status line 5433 → 5435; `../hyperswitch-lab/README.md` (port, and that the shuttle app shares the lab's proxy and outage switches)

**Interfaces:**
- `Payments::HyperswitchSetup.new(base_url:, admin_api_key:, merchant_id:, keys: { stripe_secret:, razorpay_key_id:, razorpay_key_secret: }).call -> Hash` (ids only, no secrets in the return value printed by the rake task). Idempotent: finds or creates business profile `shuttle`; sets its webhook URL to `http://host.docker.internal:3000/api/v1/webhooks/hyperswitch` with payment and refund events on; creates a merchant API key named `shuttle-office-service`; connects `stripe` (cards, INR+USD) and `razorpay` (UPI collect, INR) on that profile with `test_mode: true`; activates a priority routing rule `stripe` for the profile; ensures the card BIN rows the lab seeds exist (`POST /cards/create` for 424242, 411111, 400005, 555555, 520082, ignoring "already exists"). Writes `HYPERSWITCH_PROFILE_ID`, `HYPERSWITCH_API_KEY`, `HYPERSWITCH_PUBLISHABLE_KEY`, `HYPERSWITCH_WEBHOOK_SECRET` into `.env` (file mode 600) and prints only which keys were written.
- Processor keys read from ENV `STRIPE_TEST_SECRET_KEY`, `RAZORPAY_TEST_KEY_ID`, `RAZORPAY_TEST_KEY_SECRET`; a missing one skips that connector with a message.

- [ ] **Step 1: Write failing spec** (WebMock) that a second run creates nothing new and that output never contains the stubbed secret values.
- [ ] **Step 2: Run** — fail. **Step 3: Implement.** **Step 4: Run** — pass.
- [ ] **Step 5: Move the lab Postgres port;** run `../hyperswitch-lab/lab.sh restart` and `../hyperswitch-lab/lab.sh status` — expect `up 5435 Postgres` and router `up`.
- [ ] **Step 6: Run against the lab** `bin/rails payments:setup_hyperswitch` — expect profile, webhook, routing and BIN lines; then `curl -s localhost:8080/health`.
- [ ] **Step 7: Commit** (shuttle repo only) `chore(payments): local Hyperswitch setup task`.

### Task 16: Checkout and reservation status in the frontend

**Files:**
- Modify: `frontend/package.json` (`@juspay-tech/react-hyper-js`), `frontend/src/features/reservations/(types)/types.d.ts`, `(components)/ReservationList.tsx`, `(queries)/queries.ts`
- Create: `frontend/src/features/payments/(components)/Checkout.tsx`, `frontend/src/features/payments/(queries)/queries.ts`, `frontend/src/app/api/reservations/[uid]/payment/route.ts` (GET and POST proxy, same pattern as existing route handlers), `frontend/src/app/(dashboard)/employee/reservations/[uid]/pay/page.tsx`, `.../[uid]/result/page.tsx`
- Modify: `frontend/next.config.ts` if needed for the SDK origin; env `NEXT_PUBLIC_HYPERSWITCH_SDK_URL` (default `http://localhost:9050`), `NEXT_PUBLIC_HYPERSWITCH_URL` (default `http://localhost:8080`)

**Interfaces:**
- Consumes: Rails responses from Tasks 10 and 13. Checkout loads `HyperLoader.js` from the local SDK server and calls `window.Hyper(publishableKey, { customBackendUrl })`, as `../hyperswitch-lab/web/src/components/Checkout.tsx` does (the npm loader always fetches Juspay's hosted script).
- Booking a paid schedule navigates to `/employee/reservations/[uid]/pay`. The result page polls `GET .../payment` every 1.5 s until status is not `pending_payment`, then shows Paid / Expired / Cancelled. It never marks anything paid itself.
- Reservation list shows a status badge and, while `pending_payment` before `hold_expires_at`, a "Pay now" link and the minutes left; cancel button for pending and for confirmed-before-departure.

- [ ] **Step 1: Implement** the pages and components.
- [ ] **Step 2: Verify** `cd frontend && npm run lint && npx tsc --noEmit`.
- [ ] **Step 3: Verify in the browser** with Rails, Sidekiq, the lab and the frontend running: book a paid schedule, pay with Stripe test card the card number from ENV `E2E_CARD_NUMBER` (a public Visa success test card; never committed), see Paid and the boarding-pass email in letter_opener; book another and pay by UPI with Razorpay's test success id; switch Stripe to "Down: refuses" in the lab and confirm the payment falls back or fails as the lab README describes. Screenshot each result.
- [ ] **Step 4: Commit** `feat(frontend): pay for rides with Hyperswitch checkout`.

### Task 17: Admin pages for stops, distances and fares

**Files:**
- Modify: `config/routes.rb` (`resources :cities, only: %i[index show]`, nested `resources :stops`, `resources :stop_distances, only: %i[index update]`, `resources :fare_tables, only: %i[index show]`), `app/models/ability.rb` (admins manage; employees read cities/stops only)
- Create: controllers and services for those routes following the existing service pattern; frontend pages under `frontend/src/app/(dashboard)/admin/routing/`
- Test: `spec/requests/api/v1/stop_distances_spec.rb`

**Interfaces:**
- `PATCH /api/v1/stop_distances/:uid` with `{ override_km, override_reason }` (admin only; `override_km: null` clears it) sets `overridden_by_id`.
- Admin pages: city → stops table (name, kind, coordinates), distances table (from, to, computed km, override km, effective km, unrouted highlighted) with an inline override form, fare tables (read-only slabs).

- [ ] **Step 1: Write failing request specs:** admin sets and clears an override; employee gets 403; an override survives `ComputeForCity`.
- [ ] **Step 2: Run** — fail. **Step 3: Implement API and pages.** **Step 4: Run** specs, `npm run lint`, `npx tsc --noEmit`; screenshot the distances page.
- [ ] **Step 5: Commit** `feat(admin): stops, distances and fare tables`.

### Task 18: End-to-end test

**Files:**
- Modify: `frontend/package.json` (dev dependency `@playwright/test`, script `e2e`)
- Create: `frontend/playwright.config.ts`, `frontend/e2e/paid-ride.spec.ts`

- [ ] **Step 1: Write the test:** sign in as a seeded employee, open a priced Pune schedule, book, pay with card the card number from ENV `E2E_CARD_NUMBER` (a public Visa success test card; never committed) in the Hyperswitch iframe, expect the result page heading "Paid" within 30 s and the reservation list badge "Paid".
- [ ] **Step 2: Run** `cd frontend && npx playwright test` with the full stack running — pass.
- [ ] **Step 3: Commit** `test(e2e): paid ride happy path`.

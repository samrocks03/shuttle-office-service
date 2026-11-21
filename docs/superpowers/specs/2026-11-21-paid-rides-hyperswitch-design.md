# Paid rides: stops, distance-based fares and Hyperswitch payments

21 Nov 2026. Status: reviewed; open decisions answered. Waiting for Samarth's approval.

## Intent

Today every shuttle ride is free. From now on each employee pays a small fare per
ride. The fare follows Mumbai BEST's distance slabs (Samarth's choice), and it
depends on the road distance from the pickup stop to the office stop and on the
bus type (AC or Non-AC).

Payments go through a self-hosted Hyperswitch (the lab in
`payments-coe/hyperswitch-lab`), so the app talks to one payment API and new
processors are a dashboard setting, not code. The first processors are Razorpay
(UPI) and Stripe (cards), in test mode; PayPal and more come later.

Pune is the first city. Any other city must be added later by adding data
(stops, a fare table, a currency) and, where needed, new classes. The rule from
Samarth: tomorrow we extend the code or the database; we do not rewrite what
exists.

## Goals

1. Cities, pickup stops and office stops, with real coordinates. Pune is seeded.
2. Road distance for every pickup-to-office pair, in both directions, computed
   with OSRM (OpenStreetMap routing) and stored.
3. Fare tables per city and bus type, using BEST slabs for Pune in INR.
4. An employee sees the fare on a schedule, books, pays through the Hyperswitch
   checkout, and gets the boarding pass only after the payment is confirmed.
5. Unpaid holds expire and give the seat back. Cancelling a paid ride before
   departure refunds the fare.
6. Each changeable part (distance source, fare rule, payment gateway) sits behind
   one interface, so a new one is a new class.

## Non-goals

- Child, baggage and municipal-limit charges from BEST. Riders are adult
  employees; routes have no city-limit data.
- Routes with several stops. A schedule is one leg: one pickup stop to one
  office stop, or the reverse. The data model leaves room for this later.
- A map editor for stops. Stops come from a seed file; admins can add and edit
  them through the API.
- Passes, wallets, saved cards, subscriptions.
- Production deployment of Hyperswitch or OSRM.
- Exchange rates. Each city has one currency, and its fare table is in that
  currency.

## Anti-goals

- A booking that fails because a map service is down. Distances are computed
  ahead of time, never during a booking.
- A boarding pass for a ride that is not paid.
- A seat given back while its payment may still succeed.
- Changing existing behaviour for companies that do not use paid rides.
- Raw card data in Rails or in the Next.js server. Cards are entered only in
  the Hyperswitch checkout iframe.
- Secrets in the repo or in the browser bundle.

## How the project works today (relevant parts)

- Rails 7 API (`/api/v1`), Postgres, Sidekiq, JWT, CanCanCan roles (admin,
  employee, guest). Business logic is in service objects
  (`app/services/<model>_service/<action>.rb`, base class `Base`).
- `Company` has `name` and free-text `location`. `Bus` belongs to a company and
  has `number`, `capacity`, `model`. `Schedule` belongs to a bus and has
  free-text `start_point`, `date`, times and `available_seats`.
- `ReservationService::Create` locks the schedule, creates the reservation,
  takes a seat, then queues `ReservationConfirmationJob` (PDF boarding pass by
  email). `ReservationService::Destroy` deletes the reservation and gives the
  seat back.
- `reservations` has a unique index on `(schedule_id, user_id)`.
- Next.js 16 frontend on port 3001 calls Rails through its own route handlers
  (`frontend/src/app/api/...`), passing the JWT from an HTTP-only cookie.
  Features live in `frontend/src/features/<name>`.
- Docker compose: Postgres on host port 5433, Rails on 3000, frontend on 3001.

## Approaches considered (distance source)

| Approach | Trade-off | Decision |
|---|---|---|
| OSRM on OpenStreetMap data | Real road km, free, no account; can be self-hosted in Docker. Map data may miss very new roads; the public server is for light use. | **Picked by Samarth** |
| Google Distance Matrix | Best road data in Indian cities. Needs billing and an API key; cost per pair. | Not now; can be added as a new provider class |
| Straight line x 1.4 | Offline and instant, but only an estimate. | Kept only as a test and fallback provider |

## Design

### Extension points

Three interfaces. Each one is chosen by data, not by `if` branches.

| Interface | First implementation | Chosen by | Later |
|---|---|---|---|
| `Distances::Provider` - `matrix(sources, destinations) -> [[km, minutes]]` | `Distances::Osrm` | `cities.distance_provider` | `Distances::Google`, `Distances::Haversine` (tests, fallback) |
| `Fares::Policy` - `price(distance_km:, fare_table:) -> Fares::Quote` | `Fares::SlabPolicy` (BEST) | `fare_tables.policy` | flat fare, per-km fare, peak-hour rules |
| `Payments::Gateway` - create payment, fetch status, refund, verify webhook | `Payments::Hyperswitch` | app config | another orchestrator, or a direct gateway |

A small registry maps the stored name (for example `"osrm"`) to the class. A
new provider is a new class plus one registry line.

### Data model

All new tables, plus nullable columns on existing tables. No existing column
changes meaning.

```
cities
  name, country_code, currency (ISO, e.g. INR), time_zone,
  distance_provider (e.g. "osrm"), payments_enabled (bool, default false)

stops
  city_id, name, kind ("pickup" | "office"), company_id (offices only, nullable),
  latitude, longitude, osm_ref (nullable), active (bool)

stop_distances                     one row per ordered pair (from -> to)
  from_stop_id, to_stop_id,
  computed_km, computed_minutes, source ("osrm"), computed_at,
  override_km (nullable), override_reason, overridden_by_id
  unique (from_stop_id, to_stop_id)
  effective km = override_km if present, else computed_km

fare_tables                        versioned, never edited once used
  city_id, service_class ("non_ac" | "ac"), currency, policy ("slab"),
  effective_from, active
fare_slabs
  fare_table_id, up_to_km, amount_minor
fare_tables also store the rule beyond the last slab:
  step_km (5), step_amount_minor (500)

companies   + city_id (nullable)
buses       + service_class (string, default "non_ac")
schedules   + from_stop_id, to_stop_id (nullable; start_point stays)
reservations
            + status ("confirmed" default | "pending_payment" | "cancelled" | "expired")
            + fare_amount_minor, currency, fare_breakdown (jsonb), hold_expires_at
            + cancelled_at

payments
  reservation_id, gateway ("hyperswitch"), gateway_payment_id (unique),
  status, amount_minor, currency, connector, last_error, raw (jsonb)
refunds
  payment_id, gateway_refund_id (unique), amount_minor, status, reason
payment_webhook_events
  gateway, event_id (unique), event_type, gateway_payment_id, received_at
```

Notes:

- Money is stored as integers in the smallest unit (paise, cents).
- `service_class` is a string, not an `ac` boolean, so a third class (for
  example "premium") is a new value and a new fare table, not a migration.
- Existing reservations default to `"confirmed"`, so today's data and today's
  free flow keep working.
- The unique index on `(schedule_id, user_id)` becomes a partial unique index
  over `status IN ('pending_payment', 'confirmed')`, so an employee can book
  again after an expired or cancelled attempt. This is the one change to an
  existing constraint, and it is required.
- A reservation keeps its fare snapshot (`fare_amount_minor`,
  `fare_breakdown`). Later changes to fares or distances never change a booking.

### Distances

- `Distances::ComputeForCity` (service) takes all active stops of a city and asks
  the provider for a matrix: pickups x offices and offices x pickups. It writes
  `computed_km` and `computed_minutes`, and never touches `override_km`.
- OSRM call: the table service with `annotations=distance,duration`, one request
  per batch of stops (public server limit is about 100 coordinates per request).
  Base URL is configuration (`OSRM_URL`, default the public demo server), so a
  self-hosted OSRM in Docker is a config change.
- Runs from a rake task (`rails stops:compute_distances[pune]`) and from a
  Sidekiq job queued when a stop is created, moved or re-activated.
- If a pair has no route, the row is stored with no km and the schedule cannot
  be priced. The admin sees this and can set `override_km`.

### Pune seed data

- `db/seeds/cities/pune.yml`: city settings, about 12 pickup stops (for example
  Wakad, Baner, Aundh, Kothrud, Hadapsar, Viman Nagar, Pimple Saudagar, Shivaji
  Nagar, Kharadi, Magarpatta gate, Swargate, Pune Station) and about 6 office
  stops (for example Hinjewadi Phase 1, 2 and 3, EON IT Park Kharadi,
  Magarpatta City, Commerzone Yerawada).
- Coordinates are looked up once with OpenStreetMap search (Nominatim) while
  writing the seed file, checked, and saved in the file. The app never geocodes
  at runtime.
- `db/seeds/cities/pune_fares.yml`: the BEST tables below.

### Fares

`Fares::SlabPolicy` finds the first slab with `distance_km <= up_to_km`. Beyond
the last slab it adds `step_amount` for each started `step_km`. A partial
kilometre counts as the next slab (5.1 km is in the "up to 10 km" slab).

Pune, from BEST, INR:

| Up to km | Non-AC | AC |
|---|---|---|
| 5 | 10 | 12 |
| 10 | 15 | 20 |
| 15 | 20 | 30 |
| 20 | 30 | 35 |
| 25 | 35 | 40 |
| 30 | 40 | 45 |
| 35 | 45 | 50 |
| 40 | 50 | 55 |
| 45 | 55 | 60 |
| 50 | 60 | 65 |
| each further 5 km | +5 | +5 |

`Fares::QuoteForSchedule` (service): schedule -> bus service class -> city ->
active fare table on the ride date -> effective km of `(from_stop, to_stop)` ->
policy -> quote `{amount_minor, currency, distance_km, slab_label}`.

### Booking and payment flow

Only when the company's city has `payments_enabled`. Otherwise
`ReservationService::Create` and `Destroy` work exactly as today.

1. **Quote:** `GET /api/v1/schedules/:uid` and the schedule list include
   `fare` (amount, currency, distance, slab label) when the schedule can be
   priced.
2. **Hold:** `POST /api/v1/reservations` (same endpoint) takes the seat, saves
   the reservation as `pending_payment` with the fare snapshot and
   `hold_expires_at = now + 10 minutes`, then calls `Payments::Gateway` to
   create the payment. It returns `client_secret` and the reservation. No email
   yet. A schedule that cannot be priced cannot be booked while payments are
   on.
3. **Pay:** the frontend shows the Hyperswitch checkout
   (`@juspay-tech/react-hyper-js`, loaded from the Hyperswitch SDK server).
4. **Confirm:** `POST /api/v1/webhooks/hyperswitch` (no JWT; HMAC-SHA512
   signature check, each `event_id` handled once). On `payment_succeeded`: the
   reservation becomes `confirmed` and `ReservationConfirmationJob` is queued.
   This is the only place that confirms a paid reservation.
5. **Result page:** polls `GET /api/v1/reservations/:uid/payment`. For a
   reservation still pending, Rails asks Hyperswitch for the payment with
   `force_sync=true` and applies the same state change as the webhook. Reason:
   Razorpay cannot send its webhook to a `localhost` Hyperswitch, so for UPI the
   sync is how the result arrives.
6. **Expiry:** `ReservationHoldExpiryJob` runs at `hold_expires_at`. It first
   syncs the payment. Only if the payment is not succeeded and not still being
   processed does it mark the reservation `expired`, cancel the payment, and
   give the seat back. A payment still processing gets one more check later.
7. **Cancel:** `DELETE /api/v1/reservations/:uid` on a paid reservation before
   departure marks it `cancelled`, gives the seat back and asks for a full
   refund. Paid reservations are no longer deleted, because the payment record
   must stay. Free reservations are still deleted, as today.

State changes go through one service (`Reservations::Transition`) with a fixed
table of allowed moves, so the webhook, the sync and the expiry job cannot
disagree:

```
pending_payment -> confirmed   (a payment succeeded)
pending_payment -> expired     (hold time over, no payment succeeded)
pending_payment -> cancelled   (employee gives up before paying; seat freed)
confirmed       -> cancelled   (employee cancels before departure; refund)
```

A late `payment_succeeded` for an expired or cancelled reservation is not
ignored: the payment is refunded at once and the event is logged.

Builder-check answers (Claude's calls, 21 Nov):

- **Failed or declined payment during the hold:** the employee may try again
  until `hold_expires_at`. Each try is a new Hyperswitch payment and a new
  `payments` row; a reservation has many payments, at most one succeeded. The
  hold time does not restart. "Pay now" creates a new payment when the last one
  failed. Expiry and cancel sync and cancel every open payment of the
  reservation.
- **Cancel while pending:** allowed. It cancels open payments and frees the
  seat. If a payment then succeeds late, it is refunded (rule above).
- **Refund still pending or failed:** the reservation is `cancelled` at once;
  refund progress is on the refund row (`pending`, `succeeded`, `failed`). A
  Sidekiq job syncs pending refunds from Hyperswitch, and `refund_succeeded` /
  `refund_failed` webhooks update them too. A failed refund is shown to admins
  in the reservations admin list; retry is a manual admin action.
- **Which company decides `payments_enabled` and the fare:** the bus's
  company (the schedule belongs to the bus), through that company's city.
- **The lab's outage proxy:** the lab routes Stripe and Razorpay calls through
  its proxy on port 3100. The shuttle uses the same Hyperswitch, so the lab app
  must run during development, and its outage switches also affect shuttle
  payments. This is accepted for now; it lets the shuttle demo the same
  fallback. The lab README must say so.

### Hyperswitch setup

- A separate business profile for the shuttle app inside the lab's merchant, so
  its webhook URL (`http://host.docker.internal:3000/api/v1/webhooks/hyperswitch`)
  and routing do not clash with the lab app.
- Processors on that profile: Razorpay for UPI (INR), Stripe for cards (INR and
  USD). Stripe test mode may need "raw card data" access turned on.
- A seed script (`rails payments:setup_hyperswitch`) creates the profile, API
  key, webhook URL and routing, and writes ids to `.env`. Processor keys come
  from env variables that Samarth fills in; the script never prints them.
- Processor accounts in Hyperswitch belong to one profile, so the shuttle
  profile connects its own Stripe and Razorpay accounts (same test keys).
  The Razorpay connector in this Hyperswitch version supports UPI collect only.
- The script also makes sure card BIN data exists (as the lab seed does).
  Without it Hyperswitch leaves the card type empty and refuses card refunds.

### Frontend

- `features/fares`: fare badge on schedule cards and the schedule page
  (`Rs 35 · AC · 18 km`).
- `features/payments`: checkout page `/(dashboard)/employee/reservations/[uid]/pay`
  and result page that polls payment status. Route handlers proxy to Rails like
  the existing ones.
- Reservations list shows status (Pending payment, Paid, Cancelled, Expired)
  and a "Pay now" link while a hold is open.
- Admin: read-only pages for stops, distances (with an override form) and fare
  tables.

### Local environment

- The shuttle Postgres and the lab's Hyperswitch Postgres both use host port
  5433. Claude's call: move the lab's Hyperswitch Postgres to 5435 (the lab is
  ours to change); the shuttle project keeps 5433.
- Rails reaches Hyperswitch at `http://localhost:8080` (or
  `host.docker.internal:8080` inside Docker). Hyperswitch reaches Rails at
  `host.docker.internal:3000`.
- On Linux, containers do not resolve `host.docker.internal` by default. The
  shuttle `web` and `sidekiq` services get
  `extra_hosts: ["host.docker.internal:host-gateway"]` in `compose.yaml`.
- Playwright is not in the frontend yet; it is added as a dev dependency for the
  one end-to-end test.

### Tests

- `Fares::SlabPolicy`: boundaries 0.1, 5, 5.01, 20, 50, 50.01, 73 km, both
  classes.
- `Distances::Osrm`: request building, batching, a missing route; HTTP stubbed
  with a recorded OSRM response.
- `Distances::ComputeForCity`: overrides survive a recompute.
- Webhook: good, bad and missing signature; duplicate event; late success after
  expiry leads to a refund.
- Reservation flow: free company unchanged; paid hold, confirm, expire, cancel
  and refund; double booking blocked; re-booking after expiry allowed.
- Hold expiry job does not release a seat whose payment succeeded.
- Frontend: one Playwright run of book, pay with a test card, see Paid.

### Build order

0. Reservation access fix (see "Reservation access" below).
1. Cities, stops, distances, Pune seed, OSRM provider, rake task.
2. Fare tables, slab policy, quotes in the schedule API and UI.
3. Reservation states and the paid flow behind `payments_enabled`.
4. Hyperswitch gateway, webhook, sync, expiry, refunds, checkout UI.

Each step ships on its own and leaves the app working.

## Done means

- Pune has stops, every pickup-office pair has a distance, and a schedule shows
  its fare.
- With payments on, a booking is paid with a Stripe test card and with a
  Razorpay test UPI id, and only then is the boarding pass emailed.
- An unpaid hold expires and frees the seat; a cancel refunds the fare.
- With payments off, every existing spec still passes, except specs that relied
  on the reservation access gap, which are updated on purpose.
- No user can read, cancel or book a reservation for another user.

## Left to the builder

- Exact class and file names inside the patterns above.
- Batch size for OSRM requests.
- UI layout, as long as it follows the existing shadcn components.

## Reservation access (Samarth's decision, 21 Nov: fix everywhere)

Found in review and checked in the code: the routed controller
`app/controllers/api/v1/reservations_controller.rb` does no permission check
(the older `app/controllers/reservations_controller.rb` has
`load_and_authorize_resource`, but no route uses it). `ReservationService::Destroy`
finds a reservation by uid only, and `Create` accepts any `user_id`.

Decision: close this for every company, paid or free, as its own first step
(step 0 of the build order), before any payment work.

- Employees create, read, pay for and cancel only their own reservations.
  `Create` ignores a `user_id` param from employees and uses the logged-in user.
  `Show`, `Destroy`, `Index` and the new payment endpoints scope by owner.
- Admins keep full access.
- Guests cannot book. Booking requires a logged-in employee or admin.
- A reservation that is not the caller's returns 404, not 403, so ids are not
  confirmed to strangers.
- Existing specs that relied on the gap are updated, and new specs cover each
  rule (own vs other's reservation, employee vs admin, guest refused).

This is the one deliberate change to free-company behaviour.

## Open, needs Samarth

- None. Calls made by Claude are marked above.

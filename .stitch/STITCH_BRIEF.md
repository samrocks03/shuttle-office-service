# Shuttle Office — Google Stitch Project Brief

---

## What We Are Building

**Shuttle Office** is a corporate commute management platform. Companies contract shuttle buses for their employees' daily office commutes. The platform lets employees browse schedules, see live seat availability, and reserve their seat on the right bus — all before they leave home.

There are three distinct user roles, each with their own dashboard and set of responsibilities:

- **Employee** — the daily commuter. Browses schedules by route, books a seat, views their active reservations, can cancel.
- **Admin** — the operations manager at a company. Manages the company's bus fleet, creates and edits schedules, sees all reservations made under their company's buses.
- **Super Admin** — the platform owner. Manages all companies, all users, all buses and schedules across the entire system. Assigns roles.

The product sits in the same category as Cabriolet, Via, or corporate shuttle management tools — but with a clean, modern SaaS interface rather than clunky enterprise software.

---

## Design System

**Visual Atmosphere:**
A "transit confidence" interface — the discipline of well-designed public infrastructure meets modern SaaS precision. Think: a beautifully built airport departures board running on world-class software. Clinical, purposeful, and warm enough to feel human.

- **Density:** Balanced (4/10) — airy on marketing and empty states, dense on data-heavy tables and seat maps
- **Variance:** Asymmetric (6/10) — split-screen layouts, left-aligned hierarchy, no generic centered content
- **Motion:** Fluid (5/10) — spring physics on interactions, perpetual live-data micro-animations, staggered reveals

**Color Palette:**
- **Canvas White** (#F9FAFB) — primary background surface
- **Pure Surface** (#FFFFFF) — card and container fill
- **Charcoal Ink** (#18181B) — primary text and headlines
- **Muted Steel** (#71717A) — secondary text, metadata, labels
- **Transit Indigo** (#4F46E5) — single brand accent: CTAs, active states, focus rings, logo mark
- **Emerald Pulse** (#10B981) — live status only: availability dots, "active" badges, confirmation states
- **Deep Void** (#1E1B4B) — dark surfaces: auth brand panel, transit card mockup background
- **Whisper Border** (rgba(226,232,240,0.5)) — card borders, dividers, structural lines

**Typography:**
- Headlines and body: system-ui sans-serif (clean, OS-native)
- Data, codes, times, seat IDs: monospace (tabular-nums for seat counts and times)
- Track-tight headlines, relaxed body leading, 65ch max line width

**Component Rules:**
- Buttons: flat fill (Transit Indigo), tactile `translate-y-1px` on press, no outer glow
- Cards: `rounded-2xl`, 1px whisper border, flat white, shadow-sm only
- Inputs: label above (never floating), focus ring in Transit Indigo
- Loaders: skeletal shimmer matching element dimensions — no circular spinners
- Active nav items: solid indigo pill (white text) — unambiguous, not a tint
- Seat map: 6-column grid — available (dark blue-gray), taken (faded/strikethrough), selected (emerald fill)
- Live status: animated ping dot in Emerald Pulse, labeled "Live"

---

## Database Schema (PostgreSQL)

### Companies
| Column | Type | Notes |
|--------|------|-------|
| id | integer PK | |
| uid | UUID | unique, public-facing identifier |
| name | string | unique, required |
| location | string | city/region |
| created_at / updated_at | timestamps | |

### Roles
| Column | Type | Notes |
|--------|------|-------|
| id | integer PK | |
| uid | UUID | unique |
| name | string | e.g. "Employee", "Admin", "Super Admin" |
| role_type | integer | enum: employee=1, admin=2, super_admin=3 |

### Users
| Column | Type | Notes |
|--------|------|-------|
| id | integer PK | |
| uid | UUID | unique |
| first_name | string | required |
| last_name | string | required |
| email | string | unique, required |
| password_digest | string | bcrypt |
| phone_number | string | unique, 10 digits |
| company_id | FK → companies | required |
| role_id | FK → roles | nullable (guest until assigned) |

### Buses
| Column | Type | Notes |
|--------|------|-------|
| id | integer PK | |
| uid | UUID | unique |
| number | string | unique bus identifier (e.g. "BUS-042") |
| model | string | e.g. "Mercedes Sprinter" |
| capacity | integer | total seat count |
| company_id | FK → companies | |

### Schedules
| Column | Type | Notes |
|--------|------|-------|
| id | integer PK | |
| uid | UUID | unique |
| start_point | string | departure location |
| date | date | departure date |
| departure_time | time | |
| arrival_time | time | estimated arrival |
| available_seats | integer | real-time count, decrements on booking |
| bus_id | FK → buses | |

### Reservations
| Column | Type | Notes |
|--------|------|-------|
| id | integer PK | |
| uid | UUID | unique |
| schedule_id | FK → schedules | |
| user_id | FK → users | |
| (unique constraint) | | schedule_id + user_id — prevents double-booking |

**Key relationships:**
- Company → has many Buses, has many Users
- Bus → has many Schedules
- Schedule → has many Reservations (available_seats auto-decrements)
- User → belongs to Company + Role, has many Reservations

---

## User Roles & Flows

### Role 1: Employee (daily commuter)

**Goal:** Find a bus going near my office, pick a date, book a seat.

**Screens needed:**
1. **Employee Dashboard** — upcoming reservations widget, nearest upcoming departure with countdown, quick "Book a ride" CTA
2. **Schedule Browser** — filterable list of all schedules (date picker, route/start_point search). Each row: route name, date, departure time, arrival time, available seats badge, "Reserve" button
3. **My Reservations** — list of past and upcoming reservations. Each card: bus number, route, date+time, status (upcoming/past), cancel button for upcoming
4. **Profile** — name, email, phone, company badge, role badge

### Role 2: Admin (company operations manager)

**Goal:** Manage the company's buses and their daily schedules. See who's booked.

**Screens needed:**
1. **Admin Dashboard** — today's buses count, today's reservations count, buses at capacity count, quick-add schedule button
2. **Bus Management** — table of company buses: number, model, capacity, active schedules count. Add/edit/delete bus.
3. **Schedule Management** — table of all schedules: date, start_point, bus, departure time, arrival time, filled/total seats. Status badge (full/available). Add/edit/delete schedule.
4. **Reservations Overview** — all reservations across all company schedules. Filterable by date, bus, schedule. Shows user name, bus, route, date.

### Role 3: Super Admin (platform owner)

**Goal:** Manage the entire platform — all companies, all users, all buses, roles.

**Screens needed:**
1. **Super Admin Dashboard** — total companies, total users, total buses, total schedules, total reservations. Recent activity feed.
2. **Companies** — table: name, location, user count, bus count, created date. Add/edit/delete company.
3. **Users** — table: name, email, company, role badge, phone. Add/edit/delete user. Assign role.
4. **All Buses** — table: number, model, capacity, company name. Add/edit/delete.
5. **All Schedules** — table: start_point, date, departure/arrival, bus, company, seats filled/capacity.
6. **Roles** — list of roles with role_type. Assign users to roles.

---

## Public (Unauthenticated) Screens

### 1. Landing Page
**Layout:** Asymmetric split — left 60% content, right 40% transit card UI mockup

**Left side:**
- Small eyebrow badge: animated indigo ping dot + "Live route tracking across 14 cities"
- Large headline (2 lines): "Your office commute, / without the guesswork."
- Subtext: "Browse shuttle routes, compare arrival times, and reserve your seat — all before you leave home."
- Single primary CTA: "Find my route →"
- Stats strip (separated by vertical dividers): "127 Active routes" | "43 Partner companies" | "18.4k Rides this month" — all in monospace tabular numbers

**Right side (transit card mockup):**
- Dark indigo (#1E1B4B) card with rounded-2xl corners
- Header: "NEXT DEPARTURE" monospace label + animated emerald live dot
- Departure/arrival times in large monospace: "08:42" → "09:18" with location labels below
- Seat map: 6-column grid of 18 cells (A1–C6). Available = dark muted fill. Taken = faded/strikethrough. Selected = emerald fill (B2 is selected)
- Reserve button: "Reserve B2 — 08:42 departure" in indigo
- Footer meta: "Route #127 · 34 min away" in small monospace

**How it works section:**
- 2-column layout: left = title + description text; right = vertical stepped list
- Steps displayed as: large monospace step counter "01" "02" "03" + step title + description
- Steps: (1) Search your route, (2) Pick your seat, (3) Board and go
- Background: slightly tinted secondary, border-y dividers

### 2. Login Page
**Layout:** Full-screen split — left brand panel, right form panel

**Left panel (Deep Void #1E1B4B background):**
- Top: Logo mark (Bus icon in indigo square) + "Shuttle Office" wordmark in white
- Middle: "Trusted by 43 companies" monospace label, large quote in white, attribution name + "Senior Engineer · Harbor Logistics" in monospace
- Bottom: 2 stats side by side — "127 Active routes", "18.4k Rides this month" in white monospace

**Right panel (white background):**
- Mobile: small logo mark appears here only
- Headline: "Welcome back" + subtitle "Sign in to access your shuttle bookings"
- Form: Email label + input, Password label + input
- Submit: Full-width indigo button "Sign in"
- Footer: "Don't have an account? Register" link

### 3. Register Page
**Layout:** Same split-screen as login, mirrored

**Form fields:** First name, Last name, Email, Password, Company (dropdown from companies list), Phone number
- Submit: "Create account"
- Footer: "Already have an account? Sign in" link

---

## Shared Dashboard Chrome

### Sidebar (desktop, collapsible)
- Logo mark: Bus icon in indigo rounded square + "Shuttle" wordmark (collapses to icon-only)
- Nav items: solid indigo pill for active state (white text), zinc-500 text for inactive with zinc-100 hover
- Width: 224px expanded, 64px collapsed with icon-only tooltip

**Employee items:** Dashboard, My Reservations, Profile
**Admin items:** Dashboard, Buses, Schedules, Reservations
**Super Admin items:** Dashboard, Companies, Users, Buses, Schedules, Roles

### Top Header (dashboard)
- Left: hamburger toggle for sidebar collapse
- Right: user avatar (solid indigo circle with initial letter in white) + name + dropdown (Sign out option)
- Height: 64px, border-b, white background

### Mobile Bottom Nav
- Fixed bottom bar for mobile: home + reservations (or role-appropriate icons)
- Active icon filled in indigo, inactive in zinc-400

---

## Key UI Components to Design

### Seat Map Component
- 6-column grid (A–C rows, 1–6 columns)
- Each cell 28px × 28px, rounded-4px, monospace seat label
- States: available (dark navy), taken (faded/no interaction), selected (emerald)
- Compact enough to embed in a card or full-page

### Schedule Row / Card
- Route: "Central Hub → Tech Park" with small arrow
- Date + day of week in monospace
- Departure / Arrival times in monospace with "→" separator
- Available seats badge: emerald if >5 seats, amber if ≤5, red if full
- Reserve button (compact, indigo) or "Full" badge

### Reservation Card (Employee)
- Bus number badge in monospace (e.g. "BUS-042")
- Route and date
- Departure time prominent
- Status badge: "Upcoming" (indigo) or "Completed" (zinc)
- Cancel button (ghost/destructive, only for upcoming)

### Data Table (Admin / Super Admin)
- Clean rows with border-b dividers (no cards)
- Action column: Edit (ghost) + Delete (ghost destructive) buttons
- Sticky header
- Empty state: composed illustration with "No buses added yet" + add button
- Pagination at bottom

### Stats Card (Dashboard widgets)
- White card, rounded-2xl, shadow-sm
- Large monospace number
- Small label below in muted-steel
- Optional trend indicator (up/down arrow + % in small text)

---

## Tone and Copy Rules

- No "Elevate", "Seamless", "Unleash", "Next-Gen", "Empower", "Revolutionize"
- No generic names ("John Doe", "Acme Corp")
- Numbers are real and specific (127 routes, not "100+")
- Labels are direct: "Available seats" not "Capacity remaining"
- Empty states have personality: "No schedules yet — add the first one for this bus"
- Error messages are human: "That seat was just taken. Pick another." not "Reservation failed."

---

## Screens Priority Order for Generation

1. Landing Page (public hero — highest visual impact)
2. Login Page (split-screen auth)
3. Employee Dashboard
4. Schedule Browser (employee)
5. My Reservations (employee)
6. Admin Dashboard
7. Schedule Management table (admin)
8. Bus Management table (admin)
9. Super Admin Dashboard
10. Companies table (super admin)
11. Users table (super admin)
12. Register Page

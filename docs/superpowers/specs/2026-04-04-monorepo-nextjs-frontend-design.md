# Shuttle Office Service — Monorepo Frontend Design Spec

**Date:** 2026-04-04

**Status:** Approved

**Branch:** feat/mono-repo-with-fe

---

## 1. Overview

Add a Next.js 16 frontend to the existing Rails 7 API as a monorepo. Rails stays at root untouched. Frontend is additive in `/frontend`. One `docker compose up` runs everything behind Nginx.

### Goals

- Full public search experience (schedules, buses, companies) — SEO-optimized, server-rendered
- Three-tier authenticated dashboards: Employee, Admin, Super Admin
- Mobile-first responsive design with ShadCN components
- Server-first data fetching with TanStack Query hydration
- Cookie-based JWT auth — token never touches JavaScript
- Real-time architecture designed for expansion, polling for now

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 16 (App Router) |
| Language | TypeScript (strict) |
| UI Components | ShadCN + Tailwind CSS |
| Data Fetching | TanStack Query v5 |
| Auth | JWT in HTTP-only cookie (set by Rails) |
| Testing | Vitest + Testing Library + MSW + Cypress |
| Container | Docker + Nginx reverse proxy |
| Existing API | Rails 7 API-only + Postgres 16 + Redis + Sidekiq |

---

## 2. Monorepo Structure

Rails at root (no disruption). Frontend additive. Evolution path to Turborepo when patterns stabilize.

```
shuttle-office-service/                (project root)
├── app/                               (Rails — untouched)
├── config/
├── db/
├── Gemfile
├── frontend/                          (Next.js 16 — NEW)
│   ├── src/
│   │   ├── app/                       (ONLY pages + layouts + metadata)
│   │   ├── features/                  (ALL feature logic)
│   │   ├── shared/                    (cross-feature reusables)
│   │   ├── lib/                       (infrastructure)
│   │   └── providers/                 (QueryClientProvider, ThemeProvider)
│   ├── e2e/                           (Cypress E2E tests)
│   ├── public/
│   ├── next.config.ts
│   ├── tailwind.config.ts
│   ├── tsconfig.json
│   ├── Dockerfile
│   └── package.json
├── nginx/                             (reverse proxy — NEW)
│   └── nginx.conf
├── compose.yaml                       (extended with frontend + nginx)
└── ...
```

---

## 3. App Directory — Pages Only

The `app/` folder contains only pages, layouts, metadata, and `middleware.ts`. All business logic, components, hooks, queries, and types live in `features/`.

```
src/app/
├── (public)/                          route group: no auth required
│   ├── layout.tsx
│   ├── page.tsx                       landing / hero
│   ├── schedules/
│   │   ├── page.tsx                   thin: imports from features/schedules
│   │   └── [uid]/page.tsx             schedule detail
│   ├── companies/
│   │   ├── page.tsx
│   │   └── [uid]/page.tsx
│   └── buses/
│       └── page.tsx
├── (auth)/                            route group: login/register
│   ├── login/page.tsx
│   └── register/page.tsx
├── (dashboard)/                       route group: auth required
│   ├── layout.tsx                     unified shell (sidebar + header)
│   ├── employee/
│   │   ├── page.tsx                   employee dashboard home
│   │   ├── reservations/page.tsx
│   │   ├── book/[schedule_uid]/page.tsx
│   │   └── profile/page.tsx
│   ├── admin/
│   │   ├── page.tsx                   admin dashboard home
│   │   ├── buses/
│   │   │   ├── page.tsx
│   │   │   └── [uid]/page.tsx
│   │   ├── schedules/
│   │   │   ├── page.tsx
│   │   │   └── [uid]/page.tsx
│   │   └── reservations/page.tsx
│   └── super-admin/
│       ├── page.tsx                   super admin dashboard home
│       ├── companies/
│       │   ├── page.tsx
│       │   └── [uid]/page.tsx
│       ├── users/
│       │   ├── page.tsx
│       │   └── [uid]/page.tsx
│       ├── buses/page.tsx
│       ├── schedules/page.tsx
│       └── roles/page.tsx
├── layout.tsx                         root layout (fonts, providers, metadata)
└── middleware.ts                      auth cookie check + role routing
```

Pages are thin server shells (10-15 lines max): fetch initial data, pass as props to feature content component.

---

## 4. Features Directory — All Logic

Every feature module follows an identical structure:

```
features/{feature-name}/
├── (hooks)/
│   └── use{FeatureName}Facade.ts      facade hook — all business logic
├── (components)/
│   ├── {FeatureName}Content.tsx        main "use client" component
│   └── ...                             sub-components
├── (queries)/
│   └── queries.ts                      TanStack query keys + options
└── (types)/
    └── types.d.ts                      ambient types (no export needed)
```

### Feature Modules

| Module | Serves |
|--------|--------|
| `features/auth` | `/login`, `/register` |
| `features/landing` | `/` |
| `features/schedules` | `/schedules`, `/schedules/[uid]`, `/admin/schedules`, `/super-admin/schedules` |
| `features/booking` | `/employee/book/[schedule_uid]`, `/employee/reservations` |
| `features/fleet` | `/admin/buses`, `/admin/buses/[uid]`, `/admin/reservations`, `/super-admin/buses` |
| `features/companies` | `/companies`, `/companies/[uid]`, `/super-admin/companies` |
| `features/users` | `/employee/profile`, `/super-admin/users` |
| `features/dashboard` | `/employee`, `/admin`, `/super-admin` (role-specific widgets) |
| `features/roles` | `/super-admin/roles` |

### Facade Pattern

Every feature exposes a facade hook. Components destructure only what they need:

```typescript
// Good — destructure from facade
const { schedules, filters, applyFilter, isLoading } = useSchedulesFacade({ initialData });

// Bad — don't use as object
const facade = useSchedulesFacade({ initialData });
facade.applyFilter(...);
```

Facades own:
- TanStack Query calls (queries + mutations)
- State transformations and derived state
- Error transformation (API errors → UI-friendly messages)
- Filter/pagination/sort state

Components are pure presentational — they receive data and callbacks via destructured facade returns.

### Ambient Types (.d.ts)

Type files use `.d.ts` extension. No exports required — TypeScript picks them up via `tsconfig.json` `include`. Types are compile-time only, never runtime-generated.

---

## 5. Shared Directory

```
shared/
├── components/
│   ├── ui/                            ShadCN primitives (Button, Card, Dialog, etc.)
│   ├── layout/
│   │   ├── AppShell.tsx               dashboard wrapper (sidebar + header + main)
│   │   ├── Sidebar.tsx                collapsible, role-aware menu items
│   │   ├── Header.tsx                 breadcrumb + user avatar + mobile hamburger
│   │   ├── Footer.tsx                 public pages only
│   │   └── MobileNav.tsx             bottom tab bar for mobile dashboard
│   └── common/
│       ├── LoadingShimmer.tsx         skeleton pulse matching card/table layouts
│       ├── ErrorBoundary.tsx
│       ├── EmptyState.tsx             illustration + CTA
│       ├── SearchInput.tsx            debounced, with clear button
│       ├── Pagination.tsx             matches Rails meta shape
│       └── ConfirmDialog.tsx          reusable destructive variant
├── hooks/
│   ├── useDebounce.ts
│   ├── useMediaQuery.ts
│   └── useRealtimeChannel.ts          thin ActionCable wrapper (dormant until Phase 2)
└── types/
    └── global.d.ts                    IApiResponse, IApiError, IPaginationMeta, IUser
```

---

## 6. Infrastructure (lib/)

```
lib/
├── api-client.ts                      fetch wrapper
│                                      - server-side: uses INTERNAL_API_URL (http://web:3000)
│                                      - client-side: uses NEXT_PUBLIC_API_URL (http://localhost)
│                                      - server-side: forwards cookie from next/headers
│                                      - client-side: browser sends cookie automatically
├── query-client.ts                    TanStack Query client config
│                                      - default staleTime, retry, refetchOnWindowFocus
└── auth.ts                            cookie read/decode helpers for middleware
```

---

## 7. Authentication & Authorization

### Flow

1. User submits login → `POST /api/v1/login`
2. Rails validates credentials → sets HTTP-only cookie: `Set-Cookie: token=<jwt>; HttpOnly; Secure; SameSite=Lax; Path=/`
3. JSON response returns user data (token travels via cookie, not body)
4. Browser stores cookie automatically (same domain via Nginx)
5. Next.js `middleware.ts` reads cookie on every request

### Rails Changes (Minimal)

1. **JWT payload expansion:** Include `role_type` and `company_id` in the JWT payload alongside existing `user_id` and `user_uid`. This allows middleware to route by role without an extra API call per request.
   - New payload: `{ user_id, user_uid, role_type, company_id }`
2. **Cookie on login:** AuthController login action adds `Set-Cookie` header alongside the JSON response.
3. **Backward compatibility:** API still accepts `Authorization: Bearer <token>` for direct API consumers.

### Middleware Logic

```
middleware.ts reads 'token' cookie:
  - No cookie + public route → allow
  - No cookie + protected route → redirect to /login
  - Expired cookie → redirect to /login?expired=true&redirect=<current_url>
  - Valid cookie → decode JWT → extract role_type
    - role_type=0 (employee) accessing /admin/* → redirect to /employee
    - role_type=1 (admin) accessing /super-admin/* → redirect to /admin
    - Matching role → allow
```

### TanStack Query Manages User Data, Not Auth

- "Am I logged in?" → answered by cookie existence (middleware)
- "Who am I?" → answered by TanStack Query caching the user profile
- Login mutation `onSuccess` → invalidate `['user', 'profile']` query
- Server Components pass user profile as `initialData` → no loading flash

---

## 8. Data Fetching Strategy

### Server-First with TanStack Hydration

1. **Server Component** (page.tsx) fetches from Rails API using forwarded cookie
2. Passes data as `initialData` prop to client component
3. **Client Component** hydrates TanStack Query with `initialData` — zero loading flash
4. TanStack handles mutations, optimistic updates, refetches, pagination, search/filter

### Query Key Factories

```typescript
export const scheduleKeys = {
  all:    ['schedules'] as const,
  list:   (filters: IScheduleFilters, scope?: IScheduleScope) =>
            [...scheduleKeys.all, 'list', filters, scope] as const,
  detail: (uid: string) => [...scheduleKeys.all, 'detail', uid] as const,
};
```

### Caching Strategy

| Data | Rendering | Cache | Why |
|------|-----------|-------|-----|
| Schedules (public) | ISR `revalidate: 60` | `staleTime: 60s` | Frequently viewed, semi-static |
| Companies (public) | ISR `revalidate: 300` | `staleTime: 5min` | Rarely changes |
| Buses (public) | ISR `revalidate: 300` | `staleTime: 5min` | Rarely changes |
| Reservations (private) | SSR `revalidate: 0` | `staleTime: 0` | User-specific, always fresh |
| User profile (private) | SSR `revalidate: 0` | `staleTime: 30s` | Cached briefly client-side |
| Dashboard stats (admin) | SSR `revalidate: 0` | `staleTime: 10s` | Near real-time for admins |

---

## 9. Multi-Tenancy & Data Isolation

### Data Visibility Matrix

| Resource | Employee | Admin | Super Admin |
|----------|----------|-------|-------------|
| Schedules | All (R) | Own company (RW) | All (RW) |
| Buses | All (R) | Own company (RW) | All (RW) |
| Companies | All (R) | Own (R) | All (RW) |
| Reservations | Own (RW) | Own company (R) | All (R) |
| Users | Self (RW) | Own company (R) | All (RW) |
| Roles | — | — | All (RW) |

### Enforcement Layers

1. **Rails API (source of truth):** CanCan Ability model + repositories filter by scope
2. **Next.js Middleware (UX guard):** Route access by role_type — UX protection, not security
3. **Frontend Facades (UI scoping):** Facades accept `scope` parameter — admin gets implicit company_id, super admin gets company selector dropdown

Same facade serves multiple roles — `useSchedulesFacade({ initialData, scope })` adapts based on scope.

---

## 10. Design System

### Color Strategy — Minimal Core + Controlled Vibrancy

**Base (90% of UI):**
- Backgrounds: white, slate-50, slate-100
- Secondary text/borders: slate-500, slate-700
- Primary text/headings: slate-900

**Energy (10% of UI):**
- Primary (brand): indigo-600 — nav active, links, selected states
- Accent (CTAs): emerald-500 — book now, live status, seat available, confirmation
- Warning: amber-500 — low seats, alerts
- Danger: rose-500 — cancellation, errors

### Typography

Font: Inter (via `next/font/google`)

| Level | Style | Color | Example |
|-------|-------|-------|---------|
| Route/Title | text-lg font-bold | slate-900 | "Hyderabad → Office Campus" |
| Time/Key info | text-base font-medium | slate-800 | "08:30 AM — 09:15 AM" |
| Meta/Secondary | text-sm font-normal | slate-500 | "12 seats available · AC Bus" |
| Caption/Label | text-xs font-normal | slate-400 | "Last updated 2 min ago" |

### Micro-interactions

| Interaction | Animation | Where |
|-------------|-----------|-------|
| Seat selection | Subtle scale + color fill (indigo → emerald) | Booking seat grid |
| Booking confirmed | Confetti burst (small, 1.5s) + check morph | Confirmation dialog |
| Schedule card hover | Lift shadow md → lg, 150ms ease | Schedule list |
| Loading states | Shimmer pulse matching skeleton shape | All data pages |
| Page transitions | Fade-in 200ms on route change | All pages |
| Live seat count | Number counter animation | Schedule detail |
| Toast notifications | Slide in from top-right, auto-dismiss 4s | After mutations |
| Mobile nav | Bottom sheet with spring easing | Filter panels |

### Mobile-First Responsive

- **Mobile (< 768px):** Full-width stacked cards, bottom tab bar (Home/Rides/Profile), bottom sheet filters, hamburger header
- **Tablet (768px–1024px):** Collapsible icon-only sidebar, 2-column card grid, responsive card-tables
- **Desktop (> 1024px):** Full sidebar with labels, 3-column card grid, full data tables, side panels for detail views

---

## 11. Real-Time Architecture

### Phase 1 (Now) — Polling via TanStack Query

- Schedule detail: `refetchInterval: 15_000` (focused tab only)
- Employee reservations: `refetchInterval: 30_000`
- Admin dashboard: `refetchInterval: 10_000`

Zero infrastructure change. TanStack Query's built-in polling.

### Expansion Path

| Phase | What | Frontend Change | Backend Change |
|-------|------|-----------------|----------------|
| 1 (now) | Seat polling | `refetchInterval` in queries | None |
| 2 (toggle) | Notifications | `useRealtimeChannel` inside facades + NotificationCenter | ActionCable channels for events |
| 3 (toggle) | Live tracking | `features/tracking/` module + map | GPS ingestion → ActionCable broadcast |

### Infrastructure (Built Now, Dormant)

- `shared/hooks/useRealtimeChannel.ts` — thin ActionCable wrapper (~50 lines)
- `lib/actioncable.ts` — consumer factory, lazy-loaded

Facades are the toggle mechanism. Components destructure the same values regardless of whether data arrives via polling or WebSocket.

---

## 12. Docker Infrastructure

### Compose Architecture

```
Nginx (:80) — single entry point
├── /api/*       → Rails (:3000)
├── /api-docs*   → Rails (:3000)
└── /*           → Next.js (:3001)

Services: db (Postgres 16), redis, sidekiq, web (Rails), frontend (Next.js), nginx
```

One command: `docker compose up`

### Networking

- Browser requests go through Nginx: `http://localhost/api/*`
- Server Components fetch directly: `http://web:3000/api/*` (bypasses Nginx, faster)
- `lib/api-client.ts` picks URL based on `typeof window === 'undefined'`
- Same origin via Nginx — cookies flow seamlessly, no CORS
- WebSocket upgrade headers forwarded (ready for Phase 2)

### Environment Variables

- `.env` (root): Database, Redis, Rails credentials (existing, unchanged)
- `frontend/.env.local`: `NEXT_PUBLIC_API_URL=http://localhost`, `INTERNAL_API_URL=http://web:3000`

### Next.js Dockerfile

Multi-stage: dev stage (volume-mounted HMR) + production build (standalone output).

---

## 13. Error Handling & Loading States

### API Response Contract

Mirrors Rails' existing shape:

```typescript
interface IApiResponse<T> {
  success: boolean;
  data: T;
  message: string;
  meta?: IPaginationMeta;
}

interface IApiError {
  success: false;
  errors: { base: string[] };
}
```

### Error Boundary Strategy

- **Root layout:** Global ErrorBoundary — catastrophic only, "Something went wrong" + reload
- **Dashboard layout:** Preserves sidebar/header, shows error in content area only
- **Component level:** TanStack Query error state, inline error + retry button

### Loading States

Skeleton shimmers matching page layout shape, never spinners. Server-rendered `initialData` prevents loading flash on initial page load.

### Edge Cases

| Case | Handling |
|------|----------|
| Token expired mid-session | Middleware redirects to `/login?expired=true&redirect=<url>` |
| API 401 during client fetch | TanStack global `onError` → clear cache → redirect to /login |
| API 403 (role mismatch) | Toast: "You don't have permission" — stay on page |
| API 409 (duplicate reservation) | Toast: "You already booked this schedule" |
| API 422 (validation) | Map errors to form fields inline via facade |
| Booking race condition | Optimistic UI → if 409 conflict, revert + "Seat no longer available" |
| Network offline | TanStack pauses queries. Banner: "You're offline" |
| Empty states | Friendly illustration + contextual CTA |

Facades own all error transformation. Components receive human-readable error strings, never raw API errors.

---

## 14. Testing Strategy

### Testing Pyramid

| Level | Tool | What |
|-------|------|------|
| Unit | Vitest + renderHook | Facade hooks, utils, query key factories, auth helpers |
| Integration | Testing Library + MSW | Feature pages with mocked API, role-based rendering |
| E2E | Cypress | 5 critical user journeys against real Docker stack |

### Test Colocation

Tests live next to source in `__tests__/` directories within each feature's `(hooks)/`, `(components)/`, `(queries)/` folders.

### MSW Mocking

`shared/__mocks__/` contains API handlers and realistic response fixtures. MSW intercepts at the network level — integration tests exercise real API client, real TanStack hooks, real error handling.

### E2E Journeys (Cypress)

1. Public search → login → book ride
2. Employee cancel reservation
3. Admin create bus → create schedule
4. Super admin create company + user
5. Auth: expired token → re-login flow

---

## 15. User Flows

### Employee Books a Ride

```
Landing (/) → Search schedules (/schedules) → Schedule detail (/schedules/[uid])
→ "Book Now" CTA → /login (if unauthenticated, preserves redirect)
→ Login success → cookie set → middleware redirects by role
→ /employee dashboard → /employee/book/[schedule_uid]
→ Seat selection → Confirm → Success toast → /employee/reservations
```

### Admin Manages Fleet

```
/admin dashboard (stats + quick actions)
→ /admin/buses (CRUD table) → Add Bus (modal)
→ /admin/schedules (CRUD table) → Create Schedule (assign bus, times, seats)
→ /admin/schedules/[uid] (detail + booking list)
```

### Super Admin System Management

```
/super-admin dashboard (system-wide stats)
→ /super-admin/companies (CRUD all companies)
→ /super-admin/users (all users, role management)
→ Company selector dropdown → filters all data views by company
```

---

## 16. Frontend Best Practices

### Architecture Principles

- **SOLID** — Single responsibility components, open/closed via composition, interface segregation for props, dependency inversion via hooks/context
- **YAGNI / KISS** — applied wherever complexity isn't earned yet
- **Container/Presenter** — facades handle data, components handle rendering
- **Composition over inheritance** — compound components for complex UI
- **200 lines max** per component file

### Code Standards

- TypeScript strict mode
- Interfaces for all props and data structures (`.d.ts` ambient types)
- `next/image` for all images (no raw `<img>`)
- `next/font/google` for fonts (no external `@import`)
- `next/dynamic` for modals, charts, editors (with skeleton fallbacks)
- `<Link>` for all internal navigation (no `<a>` tags)
- Named imports only (no `import * as` or full-library imports)

### SEO (Public Pages)

- `metadata` / `generateMetadata` for all public routes
- `metadataBase` in root layout
- OpenGraph + Twitter cards for schedule and company pages
- JSON-LD structured data for schedule listings
- Canonical URLs via `alternates.canonical`

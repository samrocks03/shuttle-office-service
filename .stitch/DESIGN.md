# Design System: Shuttle Office

## 1. Visual Theme & Atmosphere

A "transit confidence" interface — the design language of well-engineered public infrastructure meets modern SaaS precision. Clinical, purposeful, and warm enough to feel human. Like a beautifully designed airport departures board running on the world's most reliable software.

Dense where information lives (seat maps, schedules, route codes), airy in navigation and marketing surfaces. Every visual choice communicates reliability and competence — no decorative noise, no AI aesthetic clichés.

- **Density:** 4 — Daily App Balanced (airy public surfaces, dense dashboard data layers)
- **Variance:** 6 — Offset Asymmetric (split-screen heroes, left-aligned hierarchy, no centered marketing content)
- **Motion:** 5 — Fluid CSS (spring physics, perpetual live-data micro-loops, staggered entrance reveals)

---

## 2. Color Palette & Roles

- **Canvas White** (#F9FAFB) — Primary background surface, Zinc-50 warmth
- **Pure Surface** (#FFFFFF) — Card fill, elevated container backgrounds
- **Charcoal Ink** (#18181B) — Primary text, headlines, Zinc-950 depth. Never pure black (#000000).
- **Muted Steel** (#71717A) — Secondary text, descriptions, metadata, form labels
- **Whisper Border** (rgba(226,232,240,0.5)) — Card borders, section dividers, 1px structural lines
- **Transit Indigo** (#4f46e5) — Single accent. CTAs, active nav states, focus rings, brand wordmark, logo mark fill. All interactive affordances use this one color.
- **Emerald Pulse** (#10b981) — Live status indicators exclusively. Real-time availability dots, "Live" badges, "Online" states. Never decorative.
- **Indigo Surface** (#eef2ff) — Subtle accent tints for eyebrow badges, step indicators, active sidebar items (light mode)
- **Deep Void** (#1e1b4b) — Transit card mockup background, brand panel backgrounds (auth split screen), dark UI surfaces

---

## 3. Typography Rules

- **Display/Headlines:** Geist — `tracking-tight`, weight-driven hierarchy (400 body → 600 subheadings → 700 display). Scale via `clamp()` or responsive utilities. Not screaming — confident.
- **Body:** Geist — `leading-relaxed`, `max-w-[65ch]`, Muted Steel (#71717A) for secondary copy. Never below 14px/0.875rem.
- **Mono:** Geist Mono — Route codes, seat numbers, departure times, live stats, step counters, timestamps. All numeric data in dashboards uses Mono. Tabular numbers (`tabular-nums`).
- **Banned:** Inter (removed from project), Times New Roman, Georgia, Garamond, Palatino. No generic serifs anywhere.
- **Scale discipline:** Headlines `tracking-tight`. Body never bold for emphasis — use color contrast instead.

---

## 4. Component Stylings

- **Primary Button:** Transit Indigo fill (#4f46e5), white text, `rounded-lg`, tactile `active:translate-y-px active:scale-[0.99]` feedback. `transition-all duration-150`. No outer glow. No shadow.
- **Ghost/Outline Button:** Transparent bg, `border border-border`, `rounded-lg`. `hover:bg-secondary`. Same tactile active state.
- **Cards:** `rounded-2xl` corners (1.5rem+), 1px Whisper Border, flat white background, `shadow-sm` only. Used only when elevation communicates hierarchy. In dense data tables: replace with `border-t` dividers and negative space.
- **Inputs:** Label strictly above input (never floating). `h-10` height. Focus ring in Transit Indigo. Helper text below in Muted Steel. Error text below in destructive red. `rounded-lg`.
- **Loaders:** Skeletal shimmer matching exact layout element dimensions. No circular spinners anywhere in the product.
- **Badges/Eyebrows:** `rounded-full`, `bg-brand-50 text-brand-700 border border-brand-200`. Small (text-xs). Live badges use Emerald.
- **Transit Card (signature component):** Deep Void (#1e1b4b) background, Geist Mono for times and seat codes, Emerald ping animation for live dot, `rounded-2xl`, `ring-1 ring-brand-800/50`. The seat map is a `grid-cols-6` of color-coded cells: available (brand-800), taken (brand-800/40), selected (accent-500).
- **Sidebar nav items (active):** Solid `bg-brand-600 text-white` pill — unambiguous, no guessing which page is active.
- **Avatar initials:** Solid `bg-brand-600 text-white` circle — never the light brand-100/brand-700 combination.

---

## 5. Layout Principles

- CSS Grid primary over Flexbox math. Never `calc()` percentage hacks for layout columns.
- Max-width containment: `max-w-7xl mx-auto px-6` on all section content. Never `px-4` on desktop.
- **Hero sections:** Split-screen (`grid-cols-[1fr_420px]`) or left-aligned ONLY. Centered hero BANNED (variance > 4).
- **Feature sections:** Zig-zag alternating rows, asymmetric 2-col (title + vertical timeline), or horizontal scroll. "3 equal feature cards" grid BANNED.
- Full-height containers: `min-h-[100dvh]` — never `h-screen` (iOS Safari jump bug).
- Section spacing: `py-20 md:py-28` for primary marketing sections. `py-16 md:py-20` for secondary.
- Internal horizontal padding: `px-6` on all containers.
- Sidebar: `w-56` expanded / `w-16` collapsed, `transition-all duration-200`.
- Dashboard main: `bg-secondary` background, `overflow-y-auto` on main content area.

---

## 6. Motion & Interaction

- **Spring physics:** `transition-all duration-150 ease-in-out` for micro-interactions. Tactile buttons use `active:translate-y-px active:scale-[0.99]`.
- **Hover states:** `transition-colors duration-150` on all links and nav items.
- **Live status:** `animate-ping` + `animate-pulse` on Emerald dots (never on decorative elements).
- **Entrance animations:** `opacity-0 translate-y-2 → opacity-100 translate-y-0` for hero content on page load.
- **Shimmer loaders:** `bg-gradient-to-r from-muted via-muted/60 to-muted animate-shimmer` matching exact layout dimensions.
- **Performance rule:** Animate exclusively `transform` and `opacity`. Never `top`, `left`, `width`, `height`, `background-color` (use `transition-colors` exception).
- **Sidebar collapse:** `transition-all duration-200` on `width` — acceptable exception as it's a layout shift user triggered.

---

## 7. Anti-Patterns (Banned)

- No Inter font — Geist and Geist Mono exclusively
- No pure black (#000000) — use Charcoal Ink (#18181B)
- No neon/outer glow box-shadows with color
- No oversaturated accent colors — Transit Indigo is calibrated
- No gradient text on large display headlines
- No centered Hero sections on high-variance pages — split-screen or left-aligned
- No 3-column equal feature cards — use zig-zag, stepped list, or 2-col asymmetric grid
- No AI copywriting: "Elevate", "Seamless", "Unleash", "Next-Gen", "Revolutionize", "Empower", "Transform"
- No generic placeholder names: "John Doe", "Acme Corp", "Nexus", "Example Inc"
- No fake round numbers: "99.99%", "100%", "50%"
- No scroll indicators: bouncing arrows, "Scroll to explore", chevron animations, parallax fades
- No broken image links — use CSS mockups, Lucide icons, or `picsum.photos` only
- No custom mouse cursors
- No emoji in any UI text
- No floating labels on form inputs
- No circular loading spinners
- No `h-screen` (use `min-h-[100dvh]`)
- No `bg-brand-100 text-brand-700` avatar style — use solid `bg-brand-600 text-white`

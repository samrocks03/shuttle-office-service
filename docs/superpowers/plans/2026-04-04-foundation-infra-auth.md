# Foundation, Infrastructure & Auth — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Get a running Next.js 16 frontend with Docker orchestration, cookie-based JWT auth, and an authenticated dashboard shell — the foundation everything else builds on.

**Architecture:** Next.js App Router with `features/` outside `app/`, facade pattern for business logic, HTTP-only cookie auth set by Rails, Nginx reverse proxy unifying both services on one port. Server Components fetch data, client components hydrate with TanStack Query.

**Tech Stack:** Next.js 16, TypeScript (strict), Tailwind CSS, ShadCN, TanStack Query v5, Docker, Nginx, Rails 7 (JWT changes)

**Spec:** `docs/superpowers/specs/2026-04-04-monorepo-nextjs-frontend-design.md`

**Plan series:**
- **Plan 1: Foundation, Infrastructure & Auth** (this plan)
- Plan 2: Public Pages & SEO
- Plan 3: Employee Dashboard & Booking
- Plan 4: Admin & Super Admin Dashboards
- Plan 5: Testing, Polish & Micro-interactions

---

## File Structure

### New files (frontend/)

```
frontend/
├── src/
│   ├── app/
│   │   ├── layout.tsx                          root layout
│   │   ├── (public)/
│   │   │   ├── layout.tsx                      public layout (header + footer)
│   │   │   └── page.tsx                        placeholder landing
│   │   ├── (auth)/
│   │   │   ├── login/page.tsx                  login page
│   │   │   └── register/page.tsx               register page
│   │   ├── (dashboard)/
│   │   │   ├── layout.tsx                      dashboard shell layout
│   │   │   ├── employee/page.tsx               placeholder employee dashboard
│   │   │   ├── admin/page.tsx                  placeholder admin dashboard
│   │   │   └── super-admin/page.tsx            placeholder super-admin dashboard
│   │   └── middleware.ts                       auth + role routing
│   ├── features/
│   │   └── auth/
│   │       ├── (types)/types.d.ts
│   │       ├── (queries)/queries.ts
│   │       ├── (hooks)/useAuthFacade.ts
│   │       └── (components)/
│   │           ├── LoginForm.tsx
│   │           └── RegisterForm.tsx
│   ├── shared/
│   │   ├── components/
│   │   │   ├── ui/                             ShadCN primitives (via CLI)
│   │   │   ├── layout/
│   │   │   │   ├── AppShell.tsx
│   │   │   │   ├── Sidebar.tsx
│   │   │   │   ├── Header.tsx
│   │   │   │   ├── MobileNav.tsx
│   │   │   │   └── Footer.tsx
│   │   │   └── common/
│   │   │       └── LoadingShimmer.tsx
│   │   ├── hooks/
│   │   │   └── useMediaQuery.ts
│   │   └── types/
│   │       └── global.d.ts
│   ├── lib/
│   │   ├── api-client.ts
│   │   ├── query-client.ts
│   │   └── auth.ts
│   └── providers/
│       └── Providers.tsx
├── public/
│   └── favicon.ico
├── e2e/                                        Cypress (empty for now)
├── .env.local
├── .env.example
├── next.config.ts
├── tailwind.config.ts
├── tsconfig.json
├── postcss.config.mjs
├── components.json                             ShadCN config
├── Dockerfile
├── package.json
└── .gitignore
```

### New files (root level)

```
nginx/
└── nginx.conf
```

### Modified files

```
compose.yaml                                    add frontend + nginx services
app/controllers/api/v1/auth_controller.rb       set cookie on login
app/services/user_service/login.rb              expand JWT payload
app/controllers/application_controller.rb       set cookie on any encode_token call
```

---

## Task 1: Initialize Next.js Project & Configuration

**Files:**
- Create: `frontend/package.json`
- Create: `frontend/tsconfig.json`
- Create: `frontend/next.config.ts`
- Create: `frontend/tailwind.config.ts`
- Create: `frontend/postcss.config.mjs`
- Create: `frontend/.gitignore`
- Create: `frontend/.env.local`
- Create: `frontend/.env.example`

- [ ] **Step 1: Create frontend directory and initialize Next.js**

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service
mkdir -p frontend
cd frontend
npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --import-alias "@/*" --no-turbopack
```

Expected: Next.js project scaffolded with `src/app/` directory, `package.json`, `tsconfig.json`, `next.config.ts`, `tailwind.config.ts`, `postcss.config.mjs`.

- [ ] **Step 2: Install core dependencies**

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service/frontend
npm install @tanstack/react-query @tanstack/react-query-devtools jose clsx tailwind-merge lucide-react
npm install -D @types/node
```

- `@tanstack/react-query` + `devtools`: data fetching + dev inspector
- `jose`: JWT decode in middleware (Edge-compatible, no Node crypto needed)
- `clsx` + `tailwind-merge`: className utility for ShadCN
- `lucide-react`: icon library (ShadCN default)

- [ ] **Step 3: Configure TypeScript strict mode**

Replace `frontend/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": [
    "next-env.d.ts",
    "**/*.ts",
    "**/*.tsx",
    "**/*.d.ts",
    ".next/types/**/*.ts"
  ],
  "exclude": ["node_modules", "e2e"]
}
```

Note: The `include` with `**/*.d.ts` ensures ambient types in `(types)/types.d.ts` files are picked up globally without explicit imports.

- [ ] **Step 4: Configure Next.js**

Replace `frontend/next.config.ts`:

```typescript
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "**.shuttle.app",
      },
    ],
  },
  async rewrites() {
    return [
      {
        source: "/api/:path*",
        destination: `${process.env.INTERNAL_API_URL || "http://localhost:3000"}/api/:path*`,
      },
    ];
  },
};

export default nextConfig;
```

- `output: "standalone"` enables the multi-stage Docker build with `server.js`
- `rewrites` proxies `/api/*` to Rails during development (Nginx handles this in Docker, but rewrites are the fallback for local dev without Docker)

- [ ] **Step 5: Configure Tailwind with design tokens**

Replace `frontend/tailwind.config.ts`:

```typescript
import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: ["class"],
  content: [
    "./src/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          50: "#eef2ff",
          100: "#e0e7ff",
          200: "#c7d2fe",
          300: "#a5b4fc",
          400: "#818cf8",
          500: "#6366f1",
          600: "#4f46e5",
          700: "#4338ca",
          800: "#3730a3",
          900: "#312e81",
          950: "#1e1b4b",
        },
        accent: {
          50: "#ecfdf5",
          100: "#d1fae5",
          200: "#a7f3d0",
          300: "#6ee7b7",
          400: "#34d399",
          500: "#10b981",
          600: "#059669",
          700: "#047857",
          800: "#065f46",
          900: "#064e3b",
          950: "#022c22",
        },
      },
      fontFamily: {
        sans: ["var(--font-inter)"],
      },
      keyframes: {
        shimmer: {
          "0%": { backgroundPosition: "-200% 0" },
          "100%": { backgroundPosition: "200% 0" },
        },
      },
      animation: {
        shimmer: "shimmer 1.5s ease-in-out infinite",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
};

export default config;
```

- `brand` maps to indigo (primary), `accent` maps to emerald (CTAs)
- `shimmer` keyframe for loading skeleton animations
- `tailwindcss-animate` is required by ShadCN

- [ ] **Step 6: Install tailwindcss-animate**

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service/frontend
npm install -D tailwindcss-animate
```

- [ ] **Step 7: Create environment files**

Create `frontend/.env.local`:

```env
NEXT_PUBLIC_API_URL=http://localhost
INTERNAL_API_URL=http://web:3000
```

Create `frontend/.env.example`:

```env
NEXT_PUBLIC_API_URL=http://localhost
INTERNAL_API_URL=http://web:3000
```

- [ ] **Step 8: Update .gitignore**

Replace `frontend/.gitignore`:

```
# dependencies
/node_modules
/.pnp
.pnp.js

# next.js
/.next/
/out/

# production
/build

# misc
.DS_Store
*.pem

# debug
npm-debug.log*

# env
.env*.local
!.env.example

# typescript
*.tsbuildinfo
next-env.d.ts
```

- [ ] **Step 9: Verify project compiles**

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service/frontend
npx next build
```

Expected: Build succeeds.

- [ ] **Step 10: Commit**

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service
git add frontend/
git commit -m "feat(frontend): initialize Next.js 16 project with TypeScript and Tailwind"
```

---

## Task 2: Docker Infrastructure

**Files:**
- Create: `frontend/Dockerfile`
- Create: `nginx/nginx.conf`
- Modify: `compose.yaml`

- [ ] **Step 1: Create Next.js Dockerfile**

Create `frontend/Dockerfile`:

```dockerfile
# ── Development stage ──────────────
FROM node:20-alpine AS dev
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev"]

# ── Production build ───────────────
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# ── Production runtime ─────────────
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
EXPOSE 3000
CMD ["node", "server.js"]
```

- [ ] **Step 2: Create Nginx configuration**

Create `nginx/nginx.conf`:

```nginx
upstream rails_api {
    server web:3000;
}

upstream nextjs_app {
    server frontend:3000;
}

server {
    listen 80;
    server_name localhost;

    # Rails API and Swagger docs
    location /api/ {
        proxy_pass http://rails_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Cookie forwarding
        proxy_pass_request_headers on;
    }

    location /api-docs {
        proxy_pass http://rails_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Rails health check
    location = /up {
        proxy_pass http://rails_api;
    }

    # ActionCable WebSocket (ready for Phase 2)
    location /cable {
        proxy_pass http://rails_api;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Next.js HMR WebSocket (development)
    location /_next/webpack-hmr {
        proxy_pass http://nextjs_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }

    # Everything else → Next.js
    location / {
        proxy_pass http://nextjs_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

- [ ] **Step 3: Extend compose.yaml with frontend and nginx services**

Modify `compose.yaml` — add these services after the existing `redis` service, and update the `web` service to remove host port exposure (Nginx is now the entry point):

The `web` service ports change from `"3000:3000"` to no host mapping (internal only). Add:

```yaml
  frontend:
    build:
      context: ./frontend
      target: dev
    container_name: shuttle_frontend
    volumes:
      - ./frontend:/app
      - /app/node_modules
      - /app/.next
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost
      - INTERNAL_API_URL=http://web:3000
    depends_on:
      - web

  nginx:
    image: nginx:alpine
    container_name: shuttle_nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - web
      - frontend
```

Remove `ports: - 3000:3000` from the `web` service (Rails is now internal-only, accessed via Nginx). If you still want direct Rails access for debugging, keep it as `"3000:3000"` but understand Nginx on `:80` is the primary entry.

- [ ] **Step 4: Verify Docker builds**

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service
docker compose build frontend nginx
```

Expected: Both images build successfully.

- [ ] **Step 5: Test full stack starts**

```bash
docker compose up -d
```

Then verify:
- `curl http://localhost/up` → Rails health check (200)
- `curl http://localhost/` → Next.js default page (200)
- `curl http://localhost/api/v1/companies` → Rails API (200 or 401)

```bash
docker compose down
```

- [ ] **Step 6: Commit**

```bash
git add frontend/Dockerfile nginx/ compose.yaml
git commit -m "feat(infra): add Docker orchestration with Nginx reverse proxy"
```

---

## Task 3: Shared Types & Lib Infrastructure

**Files:**
- Create: `frontend/src/shared/types/global.d.ts`
- Create: `frontend/src/lib/api-client.ts`
- Create: `frontend/src/lib/auth.ts`
- Create: `frontend/src/lib/query-client.ts`

- [ ] **Step 1: Create shared ambient types**

Create `frontend/src/shared/types/global.d.ts`:

```typescript
interface IApiResponse<T> {
  success: boolean;
  data: T;
  message: string;
  meta?: IPaginationMeta;
}

interface IApiError {
  success: false;
  errors: {
    base: string[];
  };
}

interface IPaginationMeta {
  current_page: number;
  per_page: number;
  total_count: number;
  total_pages: number;
}

interface IUser {
  id: string;
  uid: string;
  first_name: string;
  last_name: string;
  email: string;
  phone_number: string;
  company_id: number;
  role_id: number;
  role_type: number;
  company: {
    id: number;
    uid: string;
    name: string;
  };
}

interface ITokenPayload {
  user_id: number;
  user_uid: string;
  role_type: number;
  company_id: number;
  exp?: number;
}
```

- [ ] **Step 2: Create API client**

Create `frontend/src/lib/api-client.ts`:

```typescript
const getBaseUrl = (): string => {
  if (typeof window === "undefined") {
    return process.env.INTERNAL_API_URL || "http://localhost:3000";
  }
  return process.env.NEXT_PUBLIC_API_URL || "";
};

interface IRequestOptions extends Omit<RequestInit, "body"> {
  params?: Record<string, string | number | undefined>;
  body?: unknown;
}

async function request<T>(
  endpoint: string,
  options: IRequestOptions = {}
): Promise<T> {
  const { params, body, headers: customHeaders, ...restOptions } = options;

  const url = new URL(`${getBaseUrl()}${endpoint}`);
  if (params) {
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined) {
        url.searchParams.set(key, String(value));
      }
    });
  }

  const headers: HeadersInit = {
    "Content-Type": "application/json",
    Accept: "application/json",
    ...customHeaders,
  };

  // Server-side: forward cookies from the incoming request
  if (typeof window === "undefined") {
    const { cookies } = await import("next/headers");
    const cookieStore = await cookies();
    const token = cookieStore.get("token")?.value;
    if (token) {
      Object.assign(headers, { Authorization: `Bearer ${token}` });
    }
  }

  const response = await fetch(url.toString(), {
    ...restOptions,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({
      success: false,
      errors: { base: [`Request failed with status ${response.status}`] },
    }));
    throw { status: response.status, data: errorData };
  }

  return response.json();
}

export const apiClient = {
  get: <T>(endpoint: string, options?: IRequestOptions) =>
    request<T>(endpoint, { ...options, method: "GET" }),

  post: <T>(endpoint: string, body: unknown, options?: IRequestOptions) =>
    request<T>(endpoint, { ...options, method: "POST", body }),

  put: <T>(endpoint: string, body: unknown, options?: IRequestOptions) =>
    request<T>(endpoint, { ...options, method: "PUT", body }),

  patch: <T>(endpoint: string, body: unknown, options?: IRequestOptions) =>
    request<T>(endpoint, { ...options, method: "PATCH", body }),

  delete: <T>(endpoint: string, options?: IRequestOptions) =>
    request<T>(endpoint, { ...options, method: "DELETE" }),
};
```

Key design:
- Server-side: reads `token` cookie via `next/headers` and forwards as `Authorization: Bearer` header to Rails
- Client-side: browser sends the HTTP-only cookie automatically (same origin via Nginx)
- The Rails API stays unchanged — it still reads `Authorization: Bearer <token>`

- [ ] **Step 3: Create auth utilities**

Create `frontend/src/lib/auth.ts`:

```typescript
import { jwtVerify, decodeJwt } from "jose";

const COOKIE_NAME = "token";

/**
 * Decode JWT payload without verification (for middleware routing).
 * Middleware runs on the Edge — we decode to read role_type for routing.
 * Actual auth verification happens on Rails when the API is called.
 */
export function decodeToken(token: string): ITokenPayload | null {
  try {
    const payload = decodeJwt(token) as unknown as ITokenPayload;
    return payload;
  } catch {
    return null;
  }
}

/**
 * Check if a token is expired based on its exp claim.
 */
export function isTokenExpired(token: string): boolean {
  const payload = decodeToken(token);
  if (!payload?.exp) return false;
  return Date.now() >= payload.exp * 1000;
}

/**
 * Role constants matching Rails role_type enum.
 */
export const ROLES = {
  EMPLOYEE: 0,
  ADMIN: 1,
  SUPER_ADMIN: 2,
} as const;

/**
 * Map role_type to dashboard path prefix.
 */
export function getDashboardPath(roleType: number): string {
  switch (roleType) {
    case ROLES.ADMIN:
      return "/admin";
    case ROLES.SUPER_ADMIN:
      return "/super-admin";
    default:
      return "/employee";
  }
}

export { COOKIE_NAME };
```

- [ ] **Step 4: Create TanStack Query client**

Create `frontend/src/lib/query-client.ts`:

```typescript
import { QueryClient } from "@tanstack/react-query";

export function makeQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 60 * 1000,
        refetchOnWindowFocus: false,
        retry: 1,
      },
      mutations: {
        retry: 0,
      },
    },
  });
}

let browserQueryClient: QueryClient | undefined;

export function getQueryClient(): QueryClient {
  if (typeof window === "undefined") {
    // Server: always make a new query client
    return makeQueryClient();
  }
  // Browser: make a single client and reuse it
  if (!browserQueryClient) {
    browserQueryClient = makeQueryClient();
  }
  return browserQueryClient;
}
```

Server-side creates a fresh QueryClient per request (prevents data leaking between users). Client-side reuses a singleton.

- [ ] **Step 5: Verify types are picked up globally**

Create a temporary test file `frontend/src/lib/_type-check.ts`:

```typescript
// Verify ambient types work without imports
const testResponse: IApiResponse<string> = {
  success: true,
  data: "test",
  message: "ok",
};

const testUser: IUser = {} as IUser;
const testPayload: ITokenPayload = {} as ITokenPayload;

// If this file compiles, ambient types are working
export {};
```

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service/frontend
npx tsc --noEmit
```

Expected: No type errors. Then delete the test file:

```bash
rm frontend/src/lib/_type-check.ts
```

- [ ] **Step 6: Commit**

```bash
git add frontend/src/shared/types/ frontend/src/lib/
git commit -m "feat(frontend): add shared types, API client, auth utils, and query client"
```

---

## Task 4: Providers & Root Layout

**Files:**
- Create: `frontend/src/providers/Providers.tsx`
- Modify: `frontend/src/app/layout.tsx`
- Modify: `frontend/src/app/globals.css`

- [ ] **Step 1: Create Providers wrapper**

Create `frontend/src/providers/Providers.tsx`:

```typescript
"use client";

import { QueryClientProvider } from "@tanstack/react-query";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";
import { getQueryClient } from "@/lib/query-client";

interface IProvidersProps {
  children: React.ReactNode;
}

export function Providers({ children }: IProvidersProps) {
  const queryClient = getQueryClient();

  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  );
}
```

- [ ] **Step 2: Update globals.css with design tokens**

Replace `frontend/src/app/globals.css`:

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 222.2 84% 4.9%;
    --card: 0 0% 100%;
    --card-foreground: 222.2 84% 4.9%;
    --popover: 0 0% 100%;
    --popover-foreground: 222.2 84% 4.9%;
    --primary: 243.4 75.4% 58.6%;
    --primary-foreground: 210 40% 98%;
    --secondary: 210 40% 96.1%;
    --secondary-foreground: 222.2 47.4% 11.2%;
    --muted: 210 40% 96.1%;
    --muted-foreground: 215.4 16.3% 46.9%;
    --accent: 160 84% 39.4%;
    --accent-foreground: 0 0% 100%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 243.4 75.4% 58.6%;
    --radius: 0.5rem;
  }
}

@layer base {
  * {
    @apply border-border;
  }
  body {
    @apply bg-background text-foreground antialiased;
  }
}
```

The CSS variables map to: `--primary` = indigo-500, `--accent` = emerald-600. ShadCN components read these variables.

- [ ] **Step 3: Create root layout**

Replace `frontend/src/app/layout.tsx`:

```typescript
import type { Metadata } from "next";
import { Inter } from "next/font/google";
import { Providers } from "@/providers/Providers";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_API_URL || "http://localhost"),
  title: {
    default: "Shuttle Office — Smart Commute",
    template: "%s | Shuttle Office",
  },
  description:
    "Find and book office shuttle rides. Browse schedules, compare routes, and reserve your seat.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={inter.variable}>
      <body className="font-sans">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
```

- [ ] **Step 4: Verify build**

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service/frontend
npx next build
```

Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/providers/ frontend/src/app/layout.tsx frontend/src/app/globals.css
git commit -m "feat(frontend): add providers wrapper and root layout with Inter font"
```

---

## Task 5: ShadCN Setup & Base UI Components

**Files:**
- Create: `frontend/components.json`
- Create: `frontend/src/shared/components/ui/button.tsx` (via CLI)
- Create: `frontend/src/shared/components/ui/card.tsx` (via CLI)
- Create: `frontend/src/shared/components/ui/input.tsx` (via CLI)
- Create: `frontend/src/shared/components/ui/label.tsx` (via CLI)
- Create: `frontend/src/shared/components/ui/toast.tsx` (via CLI)
- Create: `frontend/src/shared/components/ui/toaster.tsx` (via CLI)
- Create: `frontend/src/shared/components/ui/sonner.tsx` (via CLI)
- Create: `frontend/src/shared/components/ui/skeleton.tsx` (via CLI)
- Create: `frontend/src/shared/components/ui/sheet.tsx` (via CLI)
- Create: `frontend/src/shared/components/ui/dropdown-menu.tsx` (via CLI)
- Create: `frontend/src/shared/components/ui/badge.tsx` (via CLI)
- Create: `frontend/src/shared/components/ui/separator.tsx` (via CLI)
- Create: `frontend/src/lib/utils.ts`
- Create: `frontend/src/shared/components/common/LoadingShimmer.tsx`

- [ ] **Step 1: Initialize ShadCN**

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service/frontend
npx shadcn@latest init
```

When prompted:
- Style: Default
- Base color: Slate
- CSS variables: Yes
- Components alias: `@/shared/components/ui`
- Utils alias: `@/lib/utils`

This creates `components.json` and `src/lib/utils.ts`.

Verify `components.json` has the correct aliases. If not, update it:

```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "default",
  "rsc": true,
  "tsx": true,
  "tailwind": {
    "config": "tailwind.config.ts",
    "css": "src/app/globals.css",
    "baseColor": "slate",
    "cssVariables": true
  },
  "aliases": {
    "components": "@/shared/components/ui",
    "utils": "@/lib/utils",
    "ui": "@/shared/components/ui",
    "lib": "@/lib",
    "hooks": "@/shared/hooks"
  }
}
```

- [ ] **Step 2: Install ShadCN components needed for auth and shell**

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service/frontend
npx shadcn@latest add button card input label sonner skeleton sheet dropdown-menu badge separator
```

Expected: Components installed in `src/shared/components/ui/`.

- [ ] **Step 3: Create LoadingShimmer component**

Create `frontend/src/shared/components/common/LoadingShimmer.tsx`:

```typescript
import { Skeleton } from "@/shared/components/ui/skeleton";

interface ILoadingShimmerProps {
  variant: "card" | "table" | "form" | "stats";
  count?: number;
}

export function LoadingShimmer({ variant, count = 3 }: ILoadingShimmerProps) {
  const items = Array.from({ length: count }, (_, i) => i);

  switch (variant) {
    case "card":
      return (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {items.map((i) => (
            <div key={i} className="rounded-lg border p-4 space-y-3">
              <Skeleton className="h-5 w-3/4" />
              <Skeleton className="h-4 w-1/2" />
              <Skeleton className="h-4 w-1/3" />
            </div>
          ))}
        </div>
      );
    case "table":
      return (
        <div className="space-y-2">
          <Skeleton className="h-10 w-full" />
          {items.map((i) => (
            <Skeleton key={i} className="h-12 w-full" />
          ))}
        </div>
      );
    case "form":
      return (
        <div className="space-y-4 max-w-md">
          {items.map((i) => (
            <div key={i} className="space-y-2">
              <Skeleton className="h-4 w-20" />
              <Skeleton className="h-10 w-full" />
            </div>
          ))}
          <Skeleton className="h-10 w-full" />
        </div>
      );
    case "stats":
      return (
        <div className="grid gap-4 grid-cols-2 lg:grid-cols-4">
          {Array.from({ length: 4 }, (_, i) => (
            <div key={i} className="rounded-lg border p-4 space-y-2">
              <Skeleton className="h-4 w-16" />
              <Skeleton className="h-8 w-12" />
            </div>
          ))}
        </div>
      );
  }
}
```

- [ ] **Step 4: Verify components compile**

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service/frontend
npx tsc --noEmit
```

Expected: No type errors.

- [ ] **Step 5: Commit**

```bash
git add frontend/components.json frontend/src/shared/ frontend/src/lib/utils.ts
git commit -m "feat(frontend): setup ShadCN with base components and LoadingShimmer"
```

---

## Task 6: Rails Auth Changes

**Files:**
- Modify: `app/services/user_service/login.rb` (expand JWT payload)
- Modify: `app/controllers/api/v1/auth_controller.rb` (set cookie)
- Modify: `app/controllers/application_controller.rb` (expand encode_token)

- [ ] **Step 1: Expand JWT payload in login service**

Modify `app/services/user_service/login.rb` — update the `set_data` method to include `role_type` and `company_id` in the JWT payload:

Change the `encode_token` call from:

```ruby
token = encode_token(user_id: user.id, user_uid: user.uid)
```

To:

```ruby
token = encode_token(
  user_id: user.id,
  user_uid: user.uid,
  role_type: user.role&.role_type,
  company_id: user.company_id
)
```

- [ ] **Step 2: Set HTTP-only cookie in auth controller**

Modify `app/controllers/api/v1/auth_controller.rb` — after the service returns success, set the cookie. Update the `login` method:

```ruby
def login
  result = UserService::Login.new(login_params).call

  if result.success
    token = result.data.dig(:data, :token)
    cookies[:token] = {
      value: token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax,
      path: '/'
    }
  end

  render json: result.to_h, status: result.success ? :accepted : :unauthorized
end
```

- [ ] **Step 3: Add cookie clearing on logout (prepare for future)**

Add a `logout` action to `app/controllers/api/v1/auth_controller.rb`:

```ruby
def logout
  cookies.delete(:token, path: '/')
  render json: { success: true, message: 'Logged out successfully' }, status: :ok
end
```

Update `skip_before_action` to include `logout`:

```ruby
skip_before_action :authenticate, only: %i[login register logout]
```

- [ ] **Step 4: Add logout route**

Modify `config/routes.rb` — add inside the `api/v1` namespace:

```ruby
delete '/logout', to: 'auth#logout'
```

- [ ] **Step 5: Verify Rails still works**

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service
bundle exec rails runner "puts 'Rails loads OK'"
```

Expected: `Rails loads OK`

If you have the test suite available:

```bash
bundle exec rspec spec/ --format progress
```

- [ ] **Step 6: Commit**

```bash
git add app/services/user_service/login.rb app/controllers/api/v1/auth_controller.rb config/routes.rb
git commit -m "feat(auth): expand JWT payload and set HTTP-only cookie on login"
```

---

## Task 7: Auth Feature Module

**Files:**
- Create: `frontend/src/features/auth/(types)/types.d.ts`
- Create: `frontend/src/features/auth/(queries)/queries.ts`
- Create: `frontend/src/features/auth/(hooks)/useAuthFacade.ts`
- Create: `frontend/src/features/auth/(components)/LoginForm.tsx`
- Create: `frontend/src/features/auth/(components)/RegisterForm.tsx`

- [ ] **Step 1: Create auth types**

Create `frontend/src/features/auth/(types)/types.d.ts`:

```typescript
interface ILoginRequest {
  user: {
    email: string;
    password: string;
  };
}

interface ILoginResponse {
  success: boolean;
  data: {
    user: {
      data: {
        id: string;
        type: string;
        attributes: IUser;
      };
    };
    token: string;
  };
  message: string;
}

interface IRegisterRequest {
  user: {
    first_name: string;
    last_name: string;
    phone_number: string;
    email: string;
    password: string;
    company_id: number;
    role_id?: number;
  };
}

interface IRegisterResponse {
  success: boolean;
  data: {
    user: {
      data: {
        id: string;
        type: string;
        attributes: IUser;
      };
    };
  };
  message: string;
}

interface IUserProfileResponse {
  success: boolean;
  data: {
    data: {
      id: string;
      type: string;
      attributes: IUser;
    };
  };
}

interface ICompanyOption {
  id: number;
  uid: string;
  name: string;
}
```

- [ ] **Step 2: Create auth queries**

Create `frontend/src/features/auth/(queries)/queries.ts`:

```typescript
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";

export const authKeys = {
  user: ["user", "profile"] as const,
  companies: ["companies", "list"] as const,
};

export function useLoginMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: ILoginRequest) =>
      apiClient.post<ILoginResponse>("/api/v1/login", data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: authKeys.user });
    },
  });
}

export function useRegisterMutation() {
  return useMutation({
    mutationFn: (data: IRegisterRequest) =>
      apiClient.post<IRegisterResponse>("/api/v1/register", data),
  });
}

export function useLogoutMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: () => apiClient.delete("/api/v1/logout"),
    onSuccess: () => {
      queryClient.clear();
      window.location.href = "/login";
    },
  });
}

export function useUserProfile() {
  return useQuery({
    queryKey: authKeys.user,
    queryFn: () =>
      apiClient.get<IUserProfileResponse>("/api/v1/users/me"),
    staleTime: 30 * 1000,
    retry: false,
  });
}

export function useCompanies() {
  return useQuery({
    queryKey: authKeys.companies,
    queryFn: () =>
      apiClient.get<IApiResponse<ICompanyOption[]>>("/api/v1/companies"),
    staleTime: 5 * 60 * 1000,
  });
}
```

Note: `/api/v1/users/me` may need a Rails endpoint. For now, the user profile will be extracted from the login response and cached. If a dedicated endpoint doesn't exist, Task 7 Step 3 handles this gracefully in the facade.

- [ ] **Step 3: Create auth facade**

Create `frontend/src/features/auth/(hooks)/useAuthFacade.ts`:

```typescript
"use client";

import { useState, useMemo, useCallback } from "react";
import { useRouter } from "next/navigation";
import {
  useLoginMutation,
  useRegisterMutation,
  useLogoutMutation,
  useCompanies,
} from "../(queries)/queries";

interface IUseLoginFacadeReturn {
  login: (data: ILoginRequest) => void;
  isPending: boolean;
  error: string | null;
}

export function useLoginFacade(): IUseLoginFacadeReturn {
  const router = useRouter();
  const mutation = useLoginMutation();

  const error = useMemo(() => {
    if (!mutation.error) return null;
    const err = mutation.error as { status?: number; data?: IApiError };
    if (err.data?.errors?.base?.[0]) return err.data.errors.base[0];
    if (err.status === 401) return "Invalid email or password";
    return "Something went wrong. Please try again.";
  }, [mutation.error]);

  const login = useCallback(
    (data: ILoginRequest) => {
      mutation.mutate(data, {
        onSuccess: () => {
          // Cookie is set by Rails. Redirect to home — middleware routes by role.
          router.push("/");
          router.refresh();
        },
      });
    },
    [mutation, router]
  );

  return {
    login,
    isPending: mutation.isPending,
    error,
  };
}

interface IUseRegisterFacadeReturn {
  register: (data: IRegisterRequest) => void;
  isPending: boolean;
  error: string | null;
  companies: ICompanyOption[];
  companiesLoading: boolean;
}

export function useRegisterFacade(): IUseRegisterFacadeReturn {
  const router = useRouter();
  const mutation = useRegisterMutation();
  const companiesQuery = useCompanies();

  const error = useMemo(() => {
    if (!mutation.error) return null;
    const err = mutation.error as { status?: number; data?: IApiError };
    if (err.data?.errors?.base?.[0]) return err.data.errors.base[0];
    if (err.status === 409) return "An account with this email already exists";
    return "Registration failed. Please try again.";
  }, [mutation.error]);

  const register = useCallback(
    (data: IRegisterRequest) => {
      mutation.mutate(data, {
        onSuccess: () => {
          router.push("/login?registered=true");
        },
      });
    },
    [mutation, router]
  );

  return {
    register,
    isPending: mutation.isPending,
    error,
    companies: companiesQuery.data?.data ?? [],
    companiesLoading: companiesQuery.isLoading,
  };
}

interface IUseLogoutFacadeReturn {
  logout: () => void;
  isPending: boolean;
}

export function useLogoutFacade(): IUseLogoutFacadeReturn {
  const mutation = useLogoutMutation();

  return {
    logout: () => mutation.mutate(),
    isPending: mutation.isPending,
  };
}
```

- [ ] **Step 4: Create LoginForm component**

Create `frontend/src/features/auth/(components)/LoginForm.tsx`:

```typescript
"use client";

import { useState } from "react";
import Link from "next/link";
import { Button } from "@/shared/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/shared/components/ui/card";
import { Input } from "@/shared/components/ui/input";
import { Label } from "@/shared/components/ui/label";
import { useLoginFacade } from "../(hooks)/useAuthFacade";

export function LoginForm() {
  const { login, isPending, error } = useLoginFacade();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    login({ user: { email, password } });
  };

  return (
    <Card className="w-full max-w-md">
      <CardHeader className="space-y-1">
        <CardTitle className="text-2xl font-bold">Welcome back</CardTitle>
        <CardDescription>Enter your credentials to access your account</CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          {error && (
            <div className="rounded-md bg-destructive/10 p-3 text-sm text-destructive">
              {error}
            </div>
          )}
          <div className="space-y-2">
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              type="email"
              placeholder="you@company.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              autoComplete="email"
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="password">Password</Label>
            <Input
              id="password"
              type="password"
              placeholder="Enter your password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              autoComplete="current-password"
            />
          </div>
          <Button type="submit" className="w-full" disabled={isPending}>
            {isPending ? "Signing in..." : "Sign in"}
          </Button>
          <p className="text-center text-sm text-muted-foreground">
            Don&apos;t have an account?{" "}
            <Link href="/register" className="text-primary hover:underline">
              Register
            </Link>
          </p>
        </form>
      </CardContent>
    </Card>
  );
}
```

- [ ] **Step 5: Create RegisterForm component**

Create `frontend/src/features/auth/(components)/RegisterForm.tsx`:

```typescript
"use client";

import { useState } from "react";
import Link from "next/link";
import { Button } from "@/shared/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/shared/components/ui/card";
import { Input } from "@/shared/components/ui/input";
import { Label } from "@/shared/components/ui/label";
import { useRegisterFacade } from "../(hooks)/useAuthFacade";

export function RegisterForm() {
  const { register, isPending, error, companies, companiesLoading } = useRegisterFacade();
  const [form, setForm] = useState({
    first_name: "",
    last_name: "",
    phone_number: "",
    email: "",
    password: "",
    company_id: 0,
  });

  const updateField = (field: string, value: string | number) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    register({ user: form });
  };

  return (
    <Card className="w-full max-w-md">
      <CardHeader className="space-y-1">
        <CardTitle className="text-2xl font-bold">Create an account</CardTitle>
        <CardDescription>Enter your details to get started</CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          {error && (
            <div className="rounded-md bg-destructive/10 p-3 text-sm text-destructive">
              {error}
            </div>
          )}
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="first_name">First name</Label>
              <Input
                id="first_name"
                placeholder="John"
                value={form.first_name}
                onChange={(e) => updateField("first_name", e.target.value)}
                required
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="last_name">Last name</Label>
              <Input
                id="last_name"
                placeholder="Doe"
                value={form.last_name}
                onChange={(e) => updateField("last_name", e.target.value)}
                required
              />
            </div>
          </div>
          <div className="space-y-2">
            <Label htmlFor="reg_email">Email</Label>
            <Input
              id="reg_email"
              type="email"
              placeholder="you@company.com"
              value={form.email}
              onChange={(e) => updateField("email", e.target.value)}
              required
              autoComplete="email"
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="phone">Phone number</Label>
            <Input
              id="phone"
              type="tel"
              placeholder="+91 9876543210"
              value={form.phone_number}
              onChange={(e) => updateField("phone_number", e.target.value)}
              required
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="company">Company</Label>
            <select
              id="company"
              className="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
              value={form.company_id}
              onChange={(e) => updateField("company_id", Number(e.target.value))}
              required
            >
              <option value={0} disabled>
                {companiesLoading ? "Loading..." : "Select company"}
              </option>
              {companies.map((c) => (
                <option key={c.uid} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </div>
          <div className="space-y-2">
            <Label htmlFor="reg_password">Password</Label>
            <Input
              id="reg_password"
              type="password"
              placeholder="Create a password"
              value={form.password}
              onChange={(e) => updateField("password", e.target.value)}
              required
              autoComplete="new-password"
            />
          </div>
          <Button type="submit" className="w-full" disabled={isPending}>
            {isPending ? "Creating account..." : "Create account"}
          </Button>
          <p className="text-center text-sm text-muted-foreground">
            Already have an account?{" "}
            <Link href="/login" className="text-primary hover:underline">
              Sign in
            </Link>
          </p>
        </form>
      </CardContent>
    </Card>
  );
}
```

- [ ] **Step 6: Verify compilation**

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service/frontend
npx tsc --noEmit
```

Expected: No type errors.

- [ ] **Step 7: Commit**

```bash
git add frontend/src/features/auth/
git commit -m "feat(frontend): add auth feature module with facade, queries, and form components"
```

---

## Task 8: Auth Pages & Middleware

**Files:**
- Create: `frontend/src/app/(auth)/login/page.tsx`
- Create: `frontend/src/app/(auth)/register/page.tsx`
- Create: `frontend/src/middleware.ts`

- [ ] **Step 1: Create login page**

Create `frontend/src/app/(auth)/login/page.tsx`:

```typescript
import type { Metadata } from "next";
import { LoginForm } from "@/features/auth/(components)/LoginForm";

export const metadata: Metadata = {
  title: "Sign In",
  description: "Sign in to your Shuttle Office account",
};

export default function LoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-50 p-4">
      <LoginForm />
    </main>
  );
}
```

- [ ] **Step 2: Create register page**

Create `frontend/src/app/(auth)/register/page.tsx`:

```typescript
import type { Metadata } from "next";
import { RegisterForm } from "@/features/auth/(components)/RegisterForm";

export const metadata: Metadata = {
  title: "Create Account",
  description: "Create your Shuttle Office account to start booking rides",
};

export default function RegisterPage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-50 p-4">
      <RegisterForm />
    </main>
  );
}
```

- [ ] **Step 3: Create middleware**

Create `frontend/src/middleware.ts`:

```typescript
import { NextRequest, NextResponse } from "next/server";
import { COOKIE_NAME, decodeToken, isTokenExpired, getDashboardPath, ROLES } from "@/lib/auth";

const PUBLIC_ROUTES = ["/", "/schedules", "/companies", "/buses", "/login", "/register"];

function isPublicRoute(pathname: string): boolean {
  return PUBLIC_ROUTES.some(
    (route) => pathname === route || pathname.startsWith(`${route}/`)
  );
}

function isDashboardRoute(pathname: string): boolean {
  return (
    pathname.startsWith("/employee") ||
    pathname.startsWith("/admin") ||
    pathname.startsWith("/super-admin")
  );
}

function roleMatchesPath(roleType: number, pathname: string): boolean {
  switch (roleType) {
    case ROLES.EMPLOYEE:
      return pathname.startsWith("/employee");
    case ROLES.ADMIN:
      return pathname.startsWith("/admin");
    case ROLES.SUPER_ADMIN:
      return pathname.startsWith("/super-admin");
    default:
      return false;
  }
}

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const token = request.cookies.get(COOKIE_NAME)?.value;

  // Public routes: always allow
  if (isPublicRoute(pathname)) {
    // If logged in and trying to access /login or /register, redirect to dashboard
    if ((pathname === "/login" || pathname === "/register") && token) {
      const payload = decodeToken(token);
      if (payload && !isTokenExpired(token)) {
        const dashboardPath = getDashboardPath(payload.role_type);
        return NextResponse.redirect(new URL(dashboardPath, request.url));
      }
    }
    return NextResponse.next();
  }

  // Protected routes: require valid token
  if (!token) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("redirect", pathname);
    return NextResponse.redirect(loginUrl);
  }

  // Check token expiry
  if (isTokenExpired(token)) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("expired", "true");
    loginUrl.searchParams.set("redirect", pathname);
    const response = NextResponse.redirect(loginUrl);
    response.cookies.delete(COOKIE_NAME);
    return response;
  }

  // Decode and check role
  const payload = decodeToken(token);
  if (!payload) {
    const loginUrl = new URL("/login", request.url);
    const response = NextResponse.redirect(loginUrl);
    response.cookies.delete(COOKIE_NAME);
    return response;
  }

  // Dashboard routes: verify role matches path
  if (isDashboardRoute(pathname) && !roleMatchesPath(payload.role_type, pathname)) {
    const correctPath = getDashboardPath(payload.role_type);
    return NextResponse.redirect(new URL(correctPath, request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|api/).*)",
  ],
};
```

- [ ] **Step 4: Verify compilation**

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service/frontend
npx tsc --noEmit
```

Expected: No type errors.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/app/\(auth\)/ frontend/src/middleware.ts
git commit -m "feat(frontend): add auth pages and middleware with role-based routing"
```

---

## Task 9: Dashboard Shell Components

**Files:**
- Create: `frontend/src/shared/hooks/useMediaQuery.ts`
- Create: `frontend/src/shared/components/layout/Sidebar.tsx`
- Create: `frontend/src/shared/components/layout/Header.tsx`
- Create: `frontend/src/shared/components/layout/MobileNav.tsx`
- Create: `frontend/src/shared/components/layout/AppShell.tsx`
- Create: `frontend/src/shared/components/layout/Footer.tsx`

- [ ] **Step 1: Create useMediaQuery hook**

Create `frontend/src/shared/hooks/useMediaQuery.ts`:

```typescript
"use client";

import { useState, useEffect } from "react";

export function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(false);

  useEffect(() => {
    const media = window.matchMedia(query);
    setMatches(media.matches);

    const listener = (event: MediaQueryListEvent) => setMatches(event.matches);
    media.addEventListener("change", listener);
    return () => media.removeEventListener("change", listener);
  }, [query]);

  return matches;
}
```

- [ ] **Step 2: Create Sidebar component**

Create `frontend/src/shared/components/layout/Sidebar.tsx`:

```typescript
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Home,
  CalendarDays,
  Ticket,
  Bus,
  Building2,
  Users,
  Shield,
  User,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { ROLES } from "@/lib/auth";

interface ISidebarItem {
  label: string;
  href: string;
  icon: React.ComponentType<{ className?: string }>;
}

const MENU_ITEMS: Record<number, ISidebarItem[]> = {
  [ROLES.EMPLOYEE]: [
    { label: "Dashboard", href: "/employee", icon: Home },
    { label: "My Reservations", href: "/employee/reservations", icon: Ticket },
    { label: "Profile", href: "/employee/profile", icon: User },
  ],
  [ROLES.ADMIN]: [
    { label: "Dashboard", href: "/admin", icon: Home },
    { label: "Buses", href: "/admin/buses", icon: Bus },
    { label: "Schedules", href: "/admin/schedules", icon: CalendarDays },
    { label: "Reservations", href: "/admin/reservations", icon: Ticket },
  ],
  [ROLES.SUPER_ADMIN]: [
    { label: "Dashboard", href: "/super-admin", icon: Home },
    { label: "Companies", href: "/super-admin/companies", icon: Building2 },
    { label: "Users", href: "/super-admin/users", icon: Users },
    { label: "Buses", href: "/super-admin/buses", icon: Bus },
    { label: "Schedules", href: "/super-admin/schedules", icon: CalendarDays },
    { label: "Roles", href: "/super-admin/roles", icon: Shield },
  ],
};

interface ISidebarProps {
  roleType: number;
  collapsed: boolean;
}

export function Sidebar({ roleType, collapsed }: ISidebarProps) {
  const pathname = usePathname();
  const items = MENU_ITEMS[roleType] ?? MENU_ITEMS[ROLES.EMPLOYEE];

  return (
    <aside
      className={cn(
        "hidden md:flex flex-col border-r bg-white transition-all duration-200",
        collapsed ? "w-16" : "w-56"
      )}
    >
      <div className="flex h-14 items-center border-b px-4">
        {!collapsed && (
          <span className="text-lg font-bold text-brand-600">Shuttle</span>
        )}
        {collapsed && (
          <span className="text-lg font-bold text-brand-600 mx-auto">S</span>
        )}
      </div>
      <nav className="flex-1 p-2 space-y-1">
        {items.map((item) => {
          const isActive =
            pathname === item.href ||
            (item.href !== `/${pathname.split("/")[1]}` &&
              pathname.startsWith(item.href + "/"));
          const Icon = item.icon;

          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 rounded-md px-3 py-2 text-sm transition-colors",
                isActive
                  ? "bg-brand-50 text-brand-700 font-medium"
                  : "text-slate-600 hover:bg-slate-100 hover:text-slate-900"
              )}
            >
              <Icon className="h-4 w-4 shrink-0" />
              {!collapsed && <span>{item.label}</span>}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
```

- [ ] **Step 3: Create Header component**

Create `frontend/src/shared/components/layout/Header.tsx`:

```typescript
"use client";

import { Menu, LogOut } from "lucide-react";
import { Button } from "@/shared/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/shared/components/ui/dropdown-menu";
import { useLogoutFacade } from "@/features/auth/(hooks)/useAuthFacade";

interface IHeaderProps {
  userName: string;
  onToggleSidebar: () => void;
}

export function Header({ userName, onToggleSidebar }: IHeaderProps) {
  const { logout } = useLogoutFacade();

  return (
    <header className="flex h-14 items-center justify-between border-b bg-white px-4">
      <Button
        variant="ghost"
        size="icon"
        onClick={onToggleSidebar}
        className="md:flex"
      >
        <Menu className="h-5 w-5" />
      </Button>

      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" className="gap-2">
            <div className="flex h-8 w-8 items-center justify-center rounded-full bg-brand-100 text-sm font-medium text-brand-700">
              {userName.charAt(0).toUpperCase()}
            </div>
            <span className="hidden sm:inline text-sm">{userName}</span>
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onClick={logout} className="text-destructive">
            <LogOut className="mr-2 h-4 w-4" />
            Sign out
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </header>
  );
}
```

- [ ] **Step 4: Create MobileNav component**

Create `frontend/src/shared/components/layout/MobileNav.tsx`:

```typescript
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Home, Ticket, User, Bus, Building2, CalendarDays } from "lucide-react";
import { cn } from "@/lib/utils";
import { ROLES } from "@/lib/auth";

interface IMobileNavItem {
  label: string;
  href: string;
  icon: React.ComponentType<{ className?: string }>;
}

const MOBILE_ITEMS: Record<number, IMobileNavItem[]> = {
  [ROLES.EMPLOYEE]: [
    { label: "Home", href: "/employee", icon: Home },
    { label: "Rides", href: "/employee/reservations", icon: Ticket },
    { label: "Profile", href: "/employee/profile", icon: User },
  ],
  [ROLES.ADMIN]: [
    { label: "Home", href: "/admin", icon: Home },
    { label: "Buses", href: "/admin/buses", icon: Bus },
    { label: "Schedules", href: "/admin/schedules", icon: CalendarDays },
  ],
  [ROLES.SUPER_ADMIN]: [
    { label: "Home", href: "/super-admin", icon: Home },
    { label: "Companies", href: "/super-admin/companies", icon: Building2 },
    { label: "Users", href: "/super-admin/users", icon: User },
  ],
};

interface IMobileNavProps {
  roleType: number;
}

export function MobileNav({ roleType }: IMobileNavProps) {
  const pathname = usePathname();
  const items = MOBILE_ITEMS[roleType] ?? MOBILE_ITEMS[ROLES.EMPLOYEE];

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 flex md:hidden border-t bg-white">
      {items.map((item) => {
        const isActive = pathname === item.href || pathname.startsWith(item.href + "/");
        const Icon = item.icon;

        return (
          <Link
            key={item.href}
            href={item.href}
            className={cn(
              "flex flex-1 flex-col items-center gap-1 py-2 text-xs transition-colors",
              isActive
                ? "text-brand-600 font-medium"
                : "text-slate-500"
            )}
          >
            <Icon className="h-5 w-5" />
            <span>{item.label}</span>
          </Link>
        );
      })}
    </nav>
  );
}
```

- [ ] **Step 5: Create AppShell component**

Create `frontend/src/shared/components/layout/AppShell.tsx`:

```typescript
"use client";

import { useState } from "react";
import { Sidebar } from "./Sidebar";
import { Header } from "./Header";
import { MobileNav } from "./MobileNav";

interface IAppShellProps {
  children: React.ReactNode;
  userName: string;
  roleType: number;
}

export function AppShell({ children, userName, roleType }: IAppShellProps) {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);

  return (
    <div className="flex h-screen bg-slate-50">
      <Sidebar roleType={roleType} collapsed={sidebarCollapsed} />
      <div className="flex flex-1 flex-col overflow-hidden">
        <Header
          userName={userName}
          onToggleSidebar={() => setSidebarCollapsed((prev) => !prev)}
        />
        <main className="flex-1 overflow-y-auto p-4 pb-20 md:pb-4">
          {children}
        </main>
      </div>
      <MobileNav roleType={roleType} />
    </div>
  );
}
```

- `pb-20 md:pb-4` adds bottom padding on mobile to account for the fixed bottom nav bar.

- [ ] **Step 6: Create Footer component (public pages)**

Create `frontend/src/shared/components/layout/Footer.tsx`:

```typescript
export function Footer() {
  return (
    <footer className="border-t bg-white py-8">
      <div className="container mx-auto px-4 text-center text-sm text-slate-500">
        <p>&copy; {new Date().getFullYear()} Shuttle Office. Smart commute for modern teams.</p>
      </div>
    </footer>
  );
}
```

- [ ] **Step 7: Verify compilation**

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service/frontend
npx tsc --noEmit
```

Expected: No type errors.

- [ ] **Step 8: Commit**

```bash
git add frontend/src/shared/components/layout/ frontend/src/shared/hooks/
git commit -m "feat(frontend): add dashboard shell components — AppShell, Sidebar, Header, MobileNav"
```

---

## Task 10: Dashboard Layout & Placeholder Pages

**Files:**
- Create: `frontend/src/app/(dashboard)/layout.tsx`
- Create: `frontend/src/app/(dashboard)/employee/page.tsx`
- Create: `frontend/src/app/(dashboard)/admin/page.tsx`
- Create: `frontend/src/app/(dashboard)/super-admin/page.tsx`

- [ ] **Step 1: Create dashboard layout**

Create `frontend/src/app/(dashboard)/layout.tsx`:

```typescript
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { decodeToken, COOKIE_NAME } from "@/lib/auth";
import { AppShell } from "@/shared/components/layout/AppShell";

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const cookieStore = await cookies();
  const token = cookieStore.get(COOKIE_NAME)?.value;

  if (!token) {
    redirect("/login");
  }

  const payload = decodeToken(token);
  if (!payload) {
    redirect("/login");
  }

  // For now, use a placeholder name. Plan 3 will fetch full user profile here.
  const userName = "User";

  return (
    <AppShell userName={userName} roleType={payload.role_type}>
      {children}
    </AppShell>
  );
}
```

- [ ] **Step 2: Create employee dashboard placeholder**

Create `frontend/src/app/(dashboard)/employee/page.tsx`:

```typescript
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Dashboard",
};

export default function EmployeeDashboardPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Employee Dashboard</h1>
        <p className="text-sm text-slate-500 mt-1">Your upcoming rides and quick actions</p>
      </div>
      <div className="rounded-lg border bg-white p-8 text-center text-slate-500">
        Dashboard widgets coming in Plan 3.
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Create admin dashboard placeholder**

Create `frontend/src/app/(dashboard)/admin/page.tsx`:

```typescript
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Admin Dashboard",
};

export default function AdminDashboardPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Fleet Overview</h1>
        <p className="text-sm text-slate-500 mt-1">Manage your company&apos;s buses and schedules</p>
      </div>
      <div className="rounded-lg border bg-white p-8 text-center text-slate-500">
        Admin dashboard coming in Plan 4.
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Create super-admin dashboard placeholder**

Create `frontend/src/app/(dashboard)/super-admin/page.tsx`:

```typescript
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "System Overview",
};

export default function SuperAdminDashboardPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">System Overview</h1>
        <p className="text-sm text-slate-500 mt-1">All companies, users, and fleet across the platform</p>
      </div>
      <div className="rounded-lg border bg-white p-8 text-center text-slate-500">
        Super Admin dashboard coming in Plan 4.
      </div>
    </div>
  );
}
```

- [ ] **Step 5: Verify build**

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service/frontend
npx next build
```

Expected: Build succeeds with all routes generated.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/app/\(dashboard\)/
git commit -m "feat(frontend): add dashboard layout with AppShell and placeholder pages"
```

---

## Task 11: Public Layout & Placeholder Landing

**Files:**
- Create: `frontend/src/app/(public)/layout.tsx`
- Create: `frontend/src/app/(public)/page.tsx`

- [ ] **Step 1: Create public layout**

Create `frontend/src/app/(public)/layout.tsx`:

```typescript
import Link from "next/link";
import { Footer } from "@/shared/components/layout/Footer";

export default function PublicLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen flex-col">
      <header className="sticky top-0 z-40 border-b bg-white/80 backdrop-blur-sm">
        <div className="container mx-auto flex h-14 items-center justify-between px-4">
          <Link href="/" className="text-xl font-bold text-brand-600">
            Shuttle Office
          </Link>
          <nav className="flex items-center gap-4">
            <Link
              href="/schedules"
              className="text-sm text-slate-600 hover:text-slate-900 transition-colors"
            >
              Schedules
            </Link>
            <Link
              href="/companies"
              className="text-sm text-slate-600 hover:text-slate-900 transition-colors"
            >
              Companies
            </Link>
            <Link
              href="/login"
              className="rounded-md bg-brand-600 px-4 py-2 text-sm font-medium text-white hover:bg-brand-700 transition-colors"
            >
              Sign in
            </Link>
          </nav>
        </div>
      </header>
      <main className="flex-1">{children}</main>
      <Footer />
    </div>
  );
}
```

- [ ] **Step 2: Create landing page placeholder**

Create `frontend/src/app/(public)/page.tsx`:

```typescript
import Link from "next/link";
import { Button } from "@/shared/components/ui/button";

export default function LandingPage() {
  return (
    <div>
      {/* Hero Section */}
      <section className="container mx-auto px-4 py-20 text-center">
        <h1 className="text-4xl font-bold tracking-tight text-slate-900 sm:text-5xl">
          Smart Commute for
          <span className="text-brand-600"> Modern Teams</span>
        </h1>
        <p className="mx-auto mt-4 max-w-xl text-lg text-slate-500">
          Find shuttle routes, compare schedules, and book your seat in seconds.
          Office commuting, simplified.
        </p>
        <div className="mt-8 flex justify-center gap-4">
          <Button asChild size="lg">
            <Link href="/schedules">Browse Schedules</Link>
          </Button>
          <Button asChild variant="outline" size="lg">
            <Link href="/register">Get Started</Link>
          </Button>
        </div>
      </section>

      {/* How it works */}
      <section className="border-t bg-slate-50 py-16">
        <div className="container mx-auto px-4">
          <h2 className="text-center text-2xl font-bold text-slate-900">
            How it works
          </h2>
          <div className="mt-10 grid gap-8 sm:grid-cols-3">
            {[
              {
                step: "1",
                title: "Search",
                description: "Find shuttles by route, date, or company",
              },
              {
                step: "2",
                title: "Book",
                description: "Select your seat and confirm in one tap",
              },
              {
                step: "3",
                title: "Ride",
                description: "Show up and enjoy your commute",
              },
            ].map((item) => (
              <div key={item.step} className="text-center">
                <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-brand-100 text-lg font-bold text-brand-700">
                  {item.step}
                </div>
                <h3 className="mt-4 font-semibold text-slate-900">{item.title}</h3>
                <p className="mt-2 text-sm text-slate-500">{item.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>
    </div>
  );
}
```

- [ ] **Step 3: Remove the default Next.js page**

Delete the auto-generated `frontend/src/app/page.tsx` if it exists at root level (our landing page is now at `(public)/page.tsx`):

```bash
rm -f /home/anonymous/Documents/after_work/shuttle-office-service/frontend/src/app/page.tsx
```

- [ ] **Step 4: Verify build**

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service/frontend
npx next build
```

Expected: Build succeeds. Routes include `/`, `/login`, `/register`, `/employee`, `/admin`, `/super-admin`.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/app/\(public\)/
git rm --cached frontend/src/app/page.tsx 2>/dev/null; true
git add -A frontend/src/app/
git commit -m "feat(frontend): add public layout with header, footer, and landing page"
```

---

## Task 12: Full-Stack Smoke Test

**Files:** None (verification only)

- [ ] **Step 1: Build and start all services**

```bash
cd /home/anonymous/Documents/after_work/shuttle-office-service
docker compose up --build -d
```

Wait for all services to be healthy.

- [ ] **Step 2: Verify Nginx routing**

```bash
# Rails health check
curl -s http://localhost/up | head -5
# Expected: 200 OK

# Rails API
curl -s http://localhost/api/v1/companies | python3 -m json.tool | head -5
# Expected: JSON response (200 or 401)

# Next.js landing page
curl -s http://localhost/ | grep "Shuttle Office"
# Expected: HTML containing "Shuttle Office"

# Next.js login page
curl -s http://localhost/login | grep "Welcome back"
# Expected: HTML containing "Welcome back"
```

- [ ] **Step 3: Test auth flow manually**

```bash
# Login (adjust email/password for your seed data)
curl -s -c cookies.txt http://localhost/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"test@example.com","password":"password"}}' \
  | python3 -m json.tool

# Check cookie was set
cat cookies.txt | grep token
# Expected: token cookie present with HttpOnly flag
```

- [ ] **Step 4: Verify middleware redirects**

```bash
# Without auth cookie — should redirect to /login
curl -s -o /dev/null -w "%{redirect_url}" http://localhost/employee
# Expected: http://localhost/login?redirect=/employee

# Cleanup
rm -f cookies.txt
docker compose down
```

- [ ] **Step 5: Final commit (if any fixes were needed)**

If any fixes were needed during smoke testing, commit them:

```bash
git add -A
git commit -m "fix(frontend): smoke test corrections"
```

---

## Summary

After completing all 12 tasks, you have:

- **Running monorepo**: Rails + Next.js + Nginx + Postgres + Redis + Sidekiq via `docker compose up`
- **Auth system**: JWT in HTTP-only cookies, middleware role routing, login/register pages
- **Dashboard shell**: Role-aware sidebar, header with logout, mobile bottom nav
- **Feature architecture**: `features/auth/` with full facade pattern as the template for all future features
- **Public layout**: Header, footer, landing page with hero and how-it-works
- **Shared infrastructure**: API client, query client, ambient types, ShadCN components

**Next plan:** Plan 2 — Public Pages & SEO (schedules search, company browse, bus listing)

import { cookies } from "next/headers";
import { NextResponse } from "next/server";

const BACKEND_URL = process.env.INTERNAL_API_URL || "http://localhost:3000";

/** Builds an upstream path; every segment is encoded so a uid can never add path or query parts. */
export function railsPath(...segments: string[]): string {
  return `/api/v1/${segments.map(encodeURIComponent).join("/")}`;
}

interface IProxyOptions {
  method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  /** Query parameters to send upstream (only these; nothing is forwarded implicitly). */
  query?: Record<string, string | null | undefined>;
  body?: unknown;
}

/**
 * Forwards one call to Rails with the JWT from the `token` cookie and returns Rails' status and
 * body as they are. A body that is not JSON (a proxy error page, say) becomes `{}` rather than a
 * thrown error.
 */
export async function proxyToRails(path: string, { method = "GET", query, body }: IProxyOptions = {}) {
  const cookieStore = await cookies();
  const token = cookieStore.get("token")?.value;

  const url = new URL(path, BACKEND_URL);
  for (const [key, value] of Object.entries(query ?? {})) {
    if (value) url.searchParams.set(key, value);
  }

  const upstream = await fetch(url.toString(), {
    method,
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
    cache: "no-store",
  });

  const data = await upstream.json().catch(() => ({}));
  return NextResponse.json(data, { status: upstream.status });
}

import { cookies } from "next/headers";
import { type NextRequest, NextResponse } from "next/server";

const BACKEND_URL = process.env.INTERNAL_API_URL || "http://localhost:3000";

function authHeaders(token?: string) {
  return {
    "Content-Type": "application/json",
    Accept: "application/json",
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
}

export async function GET(request: NextRequest) {
  const cookieStore = await cookies();
  const token = cookieStore.get("token")?.value;

  const url = new URL("/api/v1/reservations", BACKEND_URL);
  request.nextUrl.searchParams.forEach((value, key) => {
    url.searchParams.set(key, value);
  });

  const upstream = await fetch(url.toString(), {
    headers: authHeaders(token),
  });

  const data = await upstream.json();
  return NextResponse.json(data, { status: upstream.status });
}

export async function POST(request: NextRequest) {
  const cookieStore = await cookies();
  const token = cookieStore.get("token")?.value;
  const body = await request.json();

  const upstream = await fetch(`${BACKEND_URL}/api/v1/reservations`, {
    method: "POST",
    headers: authHeaders(token),
    body: JSON.stringify(body),
  });

  const data = await upstream.json();
  return NextResponse.json(data, { status: upstream.status });
}

import { cookies } from "next/headers";
import { type NextRequest, NextResponse } from "next/server";
import { COOKIE_NAME, decodeToken } from "@/lib/auth";

const BACKEND_URL = process.env.INTERNAL_API_URL || "http://localhost:3000";

function authHeaders(token?: string) {
  return {
    "Content-Type": "application/json",
    Accept: "application/json",
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
}

export async function GET() {
  const cookieStore = await cookies();
  const token = cookieStore.get(COOKIE_NAME)?.value;
  if (!token) {
    return NextResponse.json({ success: false, message: "Unauthorized" }, { status: 401 });
  }

  const payload = decodeToken(token);
  if (!payload?.user_uid) {
    return NextResponse.json({ success: false, message: "Invalid token" }, { status: 401 });
  }

  const upstream = await fetch(`${BACKEND_URL}/api/v1/users/${payload.user_uid}`, {
    headers: authHeaders(token),
  });

  const data = await upstream.json();
  return NextResponse.json(data, { status: upstream.status });
}

export async function PATCH(request: NextRequest) {
  const cookieStore = await cookies();
  const token = cookieStore.get(COOKIE_NAME)?.value;
  if (!token) {
    return NextResponse.json({ success: false, message: "Unauthorized" }, { status: 401 });
  }

  const payload = decodeToken(token);
  if (!payload?.user_uid) {
    return NextResponse.json({ success: false, message: "Invalid token" }, { status: 401 });
  }

  const body = await request.json();

  const upstream = await fetch(`${BACKEND_URL}/api/v1/users/${payload.user_uid}`, {
    method: "PATCH",
    headers: authHeaders(token),
    body: JSON.stringify(body),
  });

  const data = await upstream.json();
  return NextResponse.json(data, { status: upstream.status });
}

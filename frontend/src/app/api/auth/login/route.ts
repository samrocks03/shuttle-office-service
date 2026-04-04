import { cookies } from "next/headers";
import { NextResponse } from "next/server";

const BACKEND_URL = process.env.INTERNAL_API_URL || "http://localhost:3000";

export async function POST(request: Request) {
  const body = await request.json();

  const upstream = await fetch(`${BACKEND_URL}/api/v1/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify(body),
  });

  const data = await upstream.json();

  if (upstream.ok && data.data?.token) {
    const cookieStore = await cookies();
    cookieStore.set("token", data.data.token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      path: "/",
      maxAge: 60 * 60 * 24 * 7,
    });
  }

  return NextResponse.json(data, { status: upstream.status });
}

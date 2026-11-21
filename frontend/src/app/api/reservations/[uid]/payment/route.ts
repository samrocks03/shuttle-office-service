import { cookies } from "next/headers";
import { type NextRequest, NextResponse } from "next/server";

const BACKEND_URL = process.env.INTERNAL_API_URL || "http://localhost:3000";

async function proxy(method: "GET" | "POST", uid: string) {
  const cookieStore = await cookies();
  const token = cookieStore.get("token")?.value;

  const upstream = await fetch(`${BACKEND_URL}/api/v1/reservations/${uid}/payment`, {
    method,
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    cache: "no-store",
  });

  const data = await upstream.json();
  return NextResponse.json(data, { status: upstream.status });
}

// Where the reservation's payment stands (Rails syncs with Hyperswitch while it is pending).
export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ uid: string }> }
) {
  const { uid } = await params;
  return proxy("GET", uid);
}

// Starts a new payment after the last one failed or was cancelled.
export async function POST(
  _request: NextRequest,
  { params }: { params: Promise<{ uid: string }> }
) {
  const { uid } = await params;
  return proxy("POST", uid);
}

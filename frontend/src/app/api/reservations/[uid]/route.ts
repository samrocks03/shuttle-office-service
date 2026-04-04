import { cookies } from "next/headers";
import { type NextRequest, NextResponse } from "next/server";

const BACKEND_URL = process.env.INTERNAL_API_URL || "http://localhost:3000";

export async function DELETE(
  _request: NextRequest,
  { params }: { params: Promise<{ uid: string }> }
) {
  const { uid } = await params;
  const cookieStore = await cookies();
  const token = cookieStore.get("token")?.value;

  const upstream = await fetch(`${BACKEND_URL}/api/v1/reservations/${uid}`, {
    method: "DELETE",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  });

  const data = await upstream.json().catch(() => ({ success: true }));
  return NextResponse.json(data, { status: upstream.status });
}

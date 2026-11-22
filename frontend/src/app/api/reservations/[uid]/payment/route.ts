import { type NextRequest } from "next/server";
import { proxyToRails, railsPath } from "@/lib/rails-proxy";

// Where the reservation's payment stands (Rails syncs with Hyperswitch while it is pending).
export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ uid: string }> }
) {
  const { uid } = await params;
  return proxyToRails(railsPath("reservations", uid, "payment"));
}

// Starts a new payment after the last one failed or was cancelled.
export async function POST(
  _request: NextRequest,
  { params }: { params: Promise<{ uid: string }> }
) {
  const { uid } = await params;
  return proxyToRails(railsPath("reservations", uid, "payment"), { method: "POST" });
}

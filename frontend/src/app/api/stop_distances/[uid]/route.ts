import type { NextRequest } from "next/server";
import { proxyToRails, railsPath } from "@/lib/rails-proxy";

// Sets or clears the manual override on a stop pair: { override_km, override_reason }.
export async function PATCH(request: NextRequest, { params }: { params: Promise<{ uid: string }> }) {
  const { uid } = await params;
  const { override_km, override_reason } = await request.json().catch(() => ({}));
  // `override_km: null` clears the override; leaving it out is an error Rails reports.
  return proxyToRails(railsPath("stop_distances", uid), {
    method: "PATCH",
    body: { override_km, override_reason },
  });
}

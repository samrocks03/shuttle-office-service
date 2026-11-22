import type { NextRequest } from "next/server";
import { proxyToRails, railsPath } from "@/lib/rails-proxy";

export async function GET(_request: NextRequest, { params }: { params: Promise<{ uid: string }> }) {
  const { uid } = await params;
  return proxyToRails(railsPath("cities", uid));
}

import type { NextRequest } from "next/server";
import { proxyToRails, railsPath } from "@/lib/rails-proxy";

export async function GET(request: NextRequest) {
  return proxyToRails(railsPath("fare_tables"), {
    query: { city_uid: request.nextUrl.searchParams.get("city_uid") },
  });
}

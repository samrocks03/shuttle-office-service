import { proxyToRails, railsPath } from "@/lib/rails-proxy";

export async function GET() {
  return proxyToRails(railsPath("cities"));
}

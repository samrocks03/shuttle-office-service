import type { Metadata } from "next";
import { cookies } from "next/headers";
import { COOKIE_NAME, decodeToken, isTokenExpired, getDashboardPath } from "@/lib/auth";
import { ScheduleBrowser } from "@/features/schedules/(components)/ScheduleBrowser";

export const metadata: Metadata = {
  title: "Schedules",
  description: "Browse available shuttle routes, compare times, and check seat availability.",
};

export default async function SchedulesPage() {
  const cookieStore = await cookies();
  const token = cookieStore.get(COOKIE_NAME)?.value;
  let dashboardPath: string | undefined;

  if (token && !isTokenExpired(token)) {
    const payload = decodeToken(token);
    if (payload) {
      dashboardPath = getDashboardPath(payload.role_type);
    }
  }

  return <ScheduleBrowser dashboardPath={dashboardPath} />;
}

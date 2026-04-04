import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { decodeToken, COOKIE_NAME } from "@/lib/auth";
import { AppShell } from "@/shared/components/layout/AppShell";

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const cookieStore = await cookies();
  const token = cookieStore.get(COOKIE_NAME)?.value;

  if (!token) {
    redirect("/login");
  }

  const payload = decodeToken(token);
  if (!payload) {
    redirect("/login");
  }

  // Placeholder name until user profile fetch is added in Plan 3
  const userName = "User";

  return (
    <AppShell userName={userName} roleType={payload.role_type}>
      {children}
    </AppShell>
  );
}

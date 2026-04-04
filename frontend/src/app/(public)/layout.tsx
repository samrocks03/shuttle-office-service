import Link from "next/link";
import { cookies } from "next/headers";
import { Bus, User } from "lucide-react";
import { COOKIE_NAME, decodeToken, isTokenExpired, getDashboardPath } from "@/lib/auth";
import { Footer } from "@/shared/components/layout/Footer";

async function getAuthState() {
  const cookieStore = await cookies();
  const token = cookieStore.get(COOKIE_NAME)?.value;
  if (!token || isTokenExpired(token)) return null;
  const payload = decodeToken(token);
  if (!payload) return null;
  return { dashboardPath: getDashboardPath(payload.role_type) };
}

export default async function PublicLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const auth = await getAuthState();

  return (
    <div className="flex min-h-[100dvh] flex-col bg-surface">
      <header className="sticky top-0 z-40 border-b border-[#c7c4d8]/15 bg-[#fbf8ff]/80 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-6">
          <Link href="/" className="flex items-center gap-2.5">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-brand-600">
              <Bus className="h-4 w-4 text-white" />
            </div>
            <span className="text-base font-black uppercase tracking-tighter text-brand-600">
              Shuttle Office
            </span>
          </Link>

          <nav className="hidden items-center gap-8 md:flex">
            <Link
              href="/schedules"
              className="font-mono text-xs font-medium uppercase tracking-wide text-on-surface-variant transition-colors hover:text-on-surface"
            >
              Schedules
            </Link>
            <Link
              href="/companies"
              className="font-mono text-xs font-medium uppercase tracking-wide text-on-surface-variant transition-colors hover:text-on-surface"
            >
              Companies
            </Link>
          </nav>

          {auth ? (
            <Link
              href={auth.dashboardPath}
              className="inline-flex items-center gap-2 rounded-lg bg-brand-600 px-4 py-2 font-mono text-xs font-bold uppercase tracking-wider text-white transition-all hover:opacity-90 active:translate-y-px"
            >
              <User className="h-3.5 w-3.5" />
              Dashboard
            </Link>
          ) : (
            <Link
              href="/login"
              className="rounded-lg bg-brand-600 px-4 py-2 font-mono text-xs font-bold uppercase tracking-wider text-white transition-all hover:opacity-90 active:translate-y-px"
            >
              Sign in
            </Link>
          )}
        </div>
      </header>

      <main className="flex-1">{children}</main>
      <Footer />
    </div>
  );
}

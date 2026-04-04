import Link from "next/link";
import { Footer } from "@/shared/components/layout/Footer";

export default function PublicLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen flex-col">
      <header className="sticky top-0 z-40 border-b bg-white/80 backdrop-blur-sm">
        <div className="container mx-auto flex h-14 items-center justify-between px-4">
          <Link href="/" className="text-xl font-bold text-brand-600">
            Shuttle Office
          </Link>
          <nav className="flex items-center gap-4">
            <Link
              href="/schedules"
              className="text-sm text-muted-foreground hover:text-foreground transition-colors"
            >
              Schedules
            </Link>
            <Link
              href="/companies"
              className="text-sm text-muted-foreground hover:text-foreground transition-colors"
            >
              Companies
            </Link>
            <Link
              href="/login"
              className="rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90 transition-colors"
            >
              Sign in
            </Link>
          </nav>
        </div>
      </header>
      <main className="flex-1">{children}</main>
      <Footer />
    </div>
  );
}

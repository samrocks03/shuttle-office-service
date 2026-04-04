import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Admin Dashboard",
};

export default function AdminDashboardPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Fleet Overview</h1>
        <p className="text-sm text-muted-foreground mt-1">Manage your company&apos;s buses and schedules</p>
      </div>
      <div className="rounded-lg border bg-card p-8 text-center text-muted-foreground">
        Admin dashboard coming in Plan 4.
      </div>
    </div>
  );
}

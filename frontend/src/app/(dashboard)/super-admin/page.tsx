import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "System Overview",
};

export default function SuperAdminDashboardPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-foreground">System Overview</h1>
        <p className="text-sm text-muted-foreground mt-1">All companies, users, and fleet across the platform</p>
      </div>
      <div className="rounded-lg border bg-card p-8 text-center text-muted-foreground">
        Super Admin dashboard coming in Plan 4.
      </div>
    </div>
  );
}

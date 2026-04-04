import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Dashboard",
};

export default function EmployeeDashboardPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Employee Dashboard</h1>
        <p className="text-sm text-muted-foreground mt-1">Your upcoming rides and quick actions</p>
      </div>
      <div className="rounded-lg border bg-card p-8 text-center text-muted-foreground">
        Dashboard widgets coming in Plan 3.
      </div>
    </div>
  );
}

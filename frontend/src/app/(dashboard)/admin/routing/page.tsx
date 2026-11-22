import type { Metadata } from "next";
import { CityList } from "@/features/routing/(components)/CityList";

export const metadata: Metadata = {
  title: "Routing",
};

export default function AdminRoutingPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Routing</h1>
        <p className="mt-1 text-sm text-muted-foreground">Stops, distances and fare tables by city</p>
      </div>
      <CityList />
    </div>
  );
}

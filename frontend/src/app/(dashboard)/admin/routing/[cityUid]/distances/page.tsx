import type { Metadata } from "next";
import { DistancesTable } from "@/features/routing/(components)/DistancesTable";

export const metadata: Metadata = {
  title: "Distances",
};

export default async function CityDistancesPage({ params }: { params: Promise<{ cityUid: string }> }) {
  const { cityUid } = await params;
  return <DistancesTable cityUid={cityUid} />;
}

import type { Metadata } from "next";
import { StopsTable } from "@/features/routing/(components)/StopsTable";

export const metadata: Metadata = {
  title: "Stops",
};

export default async function CityStopsPage({ params }: { params: Promise<{ cityUid: string }> }) {
  const { cityUid } = await params;
  return <StopsTable cityUid={cityUid} />;
}

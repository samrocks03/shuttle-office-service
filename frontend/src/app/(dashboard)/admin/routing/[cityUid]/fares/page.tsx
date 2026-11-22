import type { Metadata } from "next";
import { FareTables } from "@/features/routing/(components)/FareTables";

export const metadata: Metadata = {
  title: "Fares",
};

export default async function CityFaresPage({ params }: { params: Promise<{ cityUid: string }> }) {
  const { cityUid } = await params;
  return <FareTables cityUid={cityUid} />;
}

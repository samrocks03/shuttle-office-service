import type { Metadata } from "next";
import { PayReservation } from "@/features/payments/(components)/PayReservation";

export const metadata: Metadata = {
  title: "Pay for your ride",
};

export default async function PayReservationPage({ params }: { params: Promise<{ uid: string }> }) {
  const { uid } = await params;
  return <PayReservation uid={uid} />;
}

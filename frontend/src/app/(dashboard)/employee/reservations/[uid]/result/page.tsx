import type { Metadata } from "next";
import { PaymentResult } from "@/features/payments/(components)/PaymentResult";

export const metadata: Metadata = {
  title: "Payment status",
};

// Hyperswitch returns the rider here (APP_FRONTEND_URL + /employee/reservations/<uid>/result).
export default async function PaymentResultPage({ params }: { params: Promise<{ uid: string }> }) {
  const { uid } = await params;
  return <PaymentResult uid={uid} />;
}

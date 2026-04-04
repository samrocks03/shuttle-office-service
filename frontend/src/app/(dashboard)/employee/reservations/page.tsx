import type { Metadata } from "next";
import { ReservationList } from "@/features/reservations/(components)/ReservationList";

export const metadata: Metadata = {
  title: "Reservations",
};

export default function EmployeeReservationsPage() {
  return <ReservationList />;
}

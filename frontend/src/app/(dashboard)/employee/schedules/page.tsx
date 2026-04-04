import type { Metadata } from "next";
import { EmployeeScheduleBrowser } from "@/features/schedules/(components)/EmployeeScheduleBrowser";

export const metadata: Metadata = {
  title: "Schedules",
};

export default function EmployeeSchedulesPage() {
  return <EmployeeScheduleBrowser />;
}

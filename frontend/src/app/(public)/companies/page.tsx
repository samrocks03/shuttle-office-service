import type { Metadata } from "next";
import { CompanyGrid } from "@/features/companies/(components)/CompanyGrid";

export const metadata: Metadata = {
  title: "Companies",
  description: "Partner companies using Shuttle Office for their employee commute.",
};

export default function CompaniesPage() {
  return <CompanyGrid />;
}

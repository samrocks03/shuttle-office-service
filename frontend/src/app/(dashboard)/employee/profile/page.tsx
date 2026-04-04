import type { Metadata } from "next";
import { ProfileCard } from "@/features/profile/(components)/ProfileCard";

export const metadata: Metadata = {
  title: "Profile",
};

export default function EmployeeProfilePage() {
  return <ProfileCard />;
}

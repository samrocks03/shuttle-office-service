import type { Metadata } from "next";
import { RegisterForm } from "@/features/auth/(components)/RegisterForm";

export const metadata: Metadata = {
  title: "Create Account",
  description: "Create your Shuttle Office account to start booking rides",
};

export default function RegisterPage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-secondary p-4">
      <RegisterForm />
    </main>
  );
}

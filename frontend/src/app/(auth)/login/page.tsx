import type { Metadata } from "next";
import { LoginForm } from "@/features/auth/(components)/LoginForm";

export const metadata: Metadata = {
  title: "Sign In",
  description: "Sign in to your Shuttle Office account",
};

export default function LoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-secondary p-4">
      <LoginForm />
    </main>
  );
}

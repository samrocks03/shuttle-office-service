"use client";

import { useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useLoginFacade } from "../(hooks)/useAuthFacade";

export function LoginForm() {
  const { login, isPending, error } = useLoginFacade();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  const handleSubmit = (e: { preventDefault(): void }) => {
    e.preventDefault();
    login({ user: { email, password } });
  };

  return (
    <div className="w-full max-w-sm">
      <div className="mb-8">
        <h1 className="text-2xl font-black tracking-tight text-on-surface">
          Welcome back
        </h1>
        <p className="mt-2 text-sm text-on-surface-variant">
          Sign in to access your shuttle bookings
        </p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-5">
        {error && (
          <div className="rounded-lg border border-destructive/20 bg-destructive/5 p-3 font-mono text-xs text-destructive">
            {error}
          </div>
        )}

        <div className="space-y-1.5">
          <Label
            htmlFor="email"
            className="font-mono text-[10px] font-bold uppercase tracking-widest text-on-surface-variant"
          >
            Email
          </Label>
          <Input
            id="email"
            type="email"
            placeholder="you@company.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            autoComplete="email"
            className="h-10 border-[#c7c4d8]/30 bg-surface-container-low focus-visible:ring-brand-600"
          />
        </div>

        <div className="space-y-1.5">
          <Label
            htmlFor="password"
            className="font-mono text-[10px] font-bold uppercase tracking-widest text-on-surface-variant"
          >
            Password
          </Label>
          <Input
            id="password"
            type="password"
            placeholder="Enter your password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            autoComplete="current-password"
            className="h-10 border-[#c7c4d8]/30 bg-surface-container-low focus-visible:ring-brand-600"
          />
        </div>

        <Button
          type="submit"
          className="h-10 w-full bg-gradient-to-r from-brand-600 to-brand-500 font-mono text-xs font-bold uppercase tracking-wider text-white transition-all hover:opacity-90 active:translate-y-px"
          disabled={isPending}
        >
          {isPending ? "Signing in..." : "Sign in"}
        </Button>

        <p className="text-center font-mono text-[11px] text-on-surface-variant">
          Don&apos;t have an account?{" "}
          <Link
            href="/register"
            className="font-bold text-brand-600 transition-colors hover:text-brand-700 hover:underline"
          >
            Register
          </Link>
        </p>
      </form>
    </div>
  );
}

import type { Metadata } from "next";
import Link from "next/link";
import { Bus } from "lucide-react";
import { RegisterForm } from "@/features/auth/(components)/RegisterForm";

export const metadata: Metadata = {
  title: "Create Account",
  description: "Create your Shuttle Office account to start booking rides",
};

export default function RegisterPage() {
  return (
    <div className="grid min-h-[100dvh] md:grid-cols-[45%_1fr]">
      {/* Left: brand panel */}
      <div className="relative hidden flex-col justify-between overflow-hidden bg-deep-void p-12 md:flex">
        {/* Dot grid texture */}
        <div
          className="pointer-events-none absolute inset-0 opacity-10"
          style={{
            backgroundImage:
              "radial-gradient(circle at 2px 2px, white 1px, transparent 0)",
            backgroundSize: "40px 40px",
          }}
        />

        {/* Logo */}
        <div className="relative z-10 flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-brand-600">
            <Bus className="h-5 w-5 text-white" />
          </div>
          <span className="text-lg font-black uppercase tracking-tighter text-white">
            Shuttle Office
          </span>
        </div>

        {/* Headline */}
        <div className="relative z-10">
          <p className="mb-6 font-mono text-[10px] uppercase tracking-widest text-white/40">
            Join the network
          </p>
          <h2 className="text-5xl font-black leading-tight tracking-tight text-white">
            Kinetic
            <br />
            Infrastructure
            <br />
            <span className="text-brand-400">Simplified.</span>
          </h2>
          <p className="mt-6 max-w-xs text-base leading-relaxed text-white/50">
            Manage fleets, track routes, and ensure every seat is filled — on
            time, every time.
          </p>
        </div>

        {/* Stats */}
        <div className="relative z-10 flex gap-10">
          <div>
            <div className="font-mono text-2xl font-bold tabular-nums text-white">
              127
            </div>
            <div className="mt-0.5 font-mono text-[10px] uppercase tracking-wide text-white/40">
              Active routes
            </div>
          </div>
          <div>
            <div className="font-mono text-2xl font-bold tabular-nums text-white">
              43
            </div>
            <div className="mt-0.5 font-mono text-[10px] uppercase tracking-wide text-white/40">
              Partner companies
            </div>
          </div>
        </div>
      </div>

      {/* Right: form panel */}
      <div className="flex flex-col items-center justify-center bg-surface px-8 py-12">
        <Link href="/" className="mb-10 flex items-center gap-2 md:hidden">
          <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-brand-600">
            <Bus className="h-3.5 w-3.5 text-white" />
          </div>
          <span className="text-sm font-black uppercase tracking-tighter text-brand-600">
            Shuttle Office
          </span>
        </Link>
        <RegisterForm />
      </div>
    </div>
  );
}

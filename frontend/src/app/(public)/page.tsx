import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { cn } from "@/lib/utils";

const TAKEN_SEATS = new Set(["A2", "A3", "B4", "B5", "C1", "C3"]);
const SELECTED_SEAT = "B2";
const ALL_SEATS = [
  "A1", "A2", "A3", "A4", "A5", "A6",
  "B1", "B2", "B3", "B4", "B5", "B6",
  "C1", "C2", "C3", "C4", "C5", "C6",
];

function TransitCardMockup() {
  return (
    <div className="relative">
      <div className="absolute -inset-6 rounded-3xl bg-brand-600/10 blur-3xl" />
      <div className="relative rounded-2xl bg-deep-void p-6 shadow-2xl ring-1 ring-white/10">
        {/* Header */}
        <div className="mb-6 flex items-center justify-between">
          <span className="font-mono text-[10px] uppercase tracking-widest text-white/40">
            Next departure
          </span>
          <div className="flex items-center gap-1.5">
            <span className="relative flex h-1.5 w-1.5">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-accent-500 opacity-75" />
              <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-accent-500" />
            </span>
            <span className="font-mono text-[10px] uppercase tracking-widest text-accent-400">
              Live
            </span>
          </div>
        </div>

        {/* Times */}
        <div className="mb-6 flex items-end justify-between">
          <div>
            <div className="font-mono text-3xl font-bold tabular-nums text-white">
              08:42
            </div>
            <div className="mt-1 font-mono text-[10px] uppercase tracking-wide text-white/40">
              Central Hub
            </div>
          </div>
          <div className="mb-2 font-mono text-sm text-white/20">——→</div>
          <div className="text-right">
            <div className="font-mono text-3xl font-bold tabular-nums text-white">
              09:18
            </div>
            <div className="mt-1 font-mono text-[10px] uppercase tracking-wide text-white/40">
              Tech Park
            </div>
          </div>
        </div>

        {/* Seat map */}
        <div className="mb-5">
          <p className="mb-2 font-mono text-[10px] uppercase tracking-widest text-white/30">
            Seat availability
          </p>
          <div className="grid grid-cols-6 gap-1">
            {ALL_SEATS.map((seat) => (
              <div
                key={seat}
                className={cn(
                  "flex h-7 items-center justify-center rounded-[4px] font-mono text-[9px] font-medium",
                  seat === SELECTED_SEAT
                    ? "bg-accent-500 text-white"
                    : TAKEN_SEATS.has(seat)
                      ? "bg-white/5 text-white/20"
                      : "bg-white/10 text-white/50"
                )}
              >
                {seat}
              </div>
            ))}
          </div>
        </div>

        {/* CTA */}
        <div className="rounded-lg bg-gradient-to-r from-brand-600 to-brand-500 py-2.5 text-center font-mono text-xs font-bold uppercase tracking-wider text-white">
          Reserve B2 — 08:42 departure
        </div>

        {/* Meta */}
        <div className="mt-4 flex items-center justify-between">
          <span className="font-mono text-[10px] text-white/30">Route #127</span>
          <span className="font-mono text-[10px] text-white/30">34 min away</span>
        </div>
      </div>
    </div>
  );
}

const HOW_IT_WORKS = [
  {
    title: "Search your route",
    description:
      "Enter your office address and find every shuttle covering your commute. Filter by time, company, or seats.",
  },
  {
    title: "Pick your seat",
    description:
      "See the live seat map for each departure. Choose your spot and lock it in before it fills up.",
  },
  {
    title: "Board and go",
    description:
      "Show your booking reference at the door. Your seat is held until departure.",
  },
];

export default function LandingPage() {
  return (
    <>
      {/* ── Hero ── */}
      <section className="mx-auto max-w-7xl px-6 py-20 md:py-28">
        <div className="grid items-center gap-16 md:grid-cols-[1fr_420px]">
          {/* Left */}
          <div>
            <div className="mb-8 inline-flex items-center gap-2 rounded-full border border-[#c7c4d8]/30 bg-surface-container-low px-3 py-1.5">
              <span className="relative flex h-1.5 w-1.5">
                <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-brand-400 opacity-75" />
                <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-brand-600" />
              </span>
              <span className="font-mono text-[11px] font-medium uppercase tracking-wider text-brand-600">
                Live route tracking · 14 cities
              </span>
            </div>

            <h1 className="text-5xl font-black tracking-tight text-on-surface md:text-6xl leading-[1.05]">
              Your office commute,
              <br />
              <span className="text-brand-600">without the guesswork.</span>
            </h1>

            <p className="mt-6 max-w-md text-lg leading-relaxed text-on-surface-variant">
              Browse shuttle routes, compare arrival times, and reserve your
              seat — all before you leave home.
            </p>

            <div className="mt-10">
              <Link
                href="/schedules"
                className="inline-flex items-center gap-2 rounded-lg bg-gradient-to-r from-brand-600 to-brand-500 px-6 py-3 font-mono text-sm font-bold uppercase tracking-wider text-white shadow-sm transition-all hover:opacity-90 active:translate-y-px active:scale-[0.99]"
              >
                Find my route
                <ArrowRight className="h-4 w-4" />
              </Link>
            </div>

            {/* Stats */}
            <div className="mt-12 flex items-center gap-8 border-t border-[#c7c4d8]/20 pt-8">
              <div>
                <div className="font-mono text-2xl font-bold tabular-nums text-on-surface">
                  127
                </div>
                <div className="mt-0.5 font-mono text-[10px] uppercase tracking-wide text-on-surface-variant">
                  Active routes
                </div>
              </div>
              <div className="h-8 w-px bg-outline-variant/30" />
              <div>
                <div className="font-mono text-2xl font-bold tabular-nums text-on-surface">
                  43
                </div>
                <div className="mt-0.5 font-mono text-[10px] uppercase tracking-wide text-on-surface-variant">
                  Partner companies
                </div>
              </div>
              <div className="h-8 w-px bg-outline-variant/30" />
              <div>
                <div className="font-mono text-2xl font-bold tabular-nums text-on-surface">
                  18.4k
                </div>
                <div className="mt-0.5 font-mono text-[10px] uppercase tracking-wide text-on-surface-variant">
                  Rides this month
                </div>
              </div>
            </div>
          </div>

          {/* Right: transit card */}
          <TransitCardMockup />
        </div>
      </section>

      {/* ── How it works ── */}
      <section className="bg-surface-container-low py-20">
        <div className="mx-auto max-w-7xl px-6">
          <div className="grid gap-16 md:grid-cols-2 md:items-start">
            {/* Title */}
            <div>
              <p className="mb-4 font-mono text-[10px] uppercase tracking-widest text-on-surface-variant">
                How it works
              </p>
              <h2 className="text-3xl font-black tracking-tight text-on-surface">
                Three steps to your seat
              </h2>
              <p className="mt-4 max-w-sm leading-relaxed text-on-surface-variant">
                No app to download. No hold music. Find your route, pick your
                spot, and ride.
              </p>
            </div>

            {/* Steps */}
            <div className="divide-y divide-[#c7c4d8]/20">
              {HOW_IT_WORKS.map((step, i) => (
                <div
                  key={step.title}
                  className="flex items-start gap-6 py-6 first:pt-0 last:pb-0"
                >
                  <div className="shrink-0 font-mono text-4xl font-black leading-none tabular-nums text-brand-600/20">
                    0{i + 1}
                  </div>
                  <div className="pt-1">
                    <h3 className="font-bold text-on-surface">{step.title}</h3>
                    <p className="mt-1 text-sm leading-relaxed text-on-surface-variant">
                      {step.description}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>
    </>
  );
}

import type { Metadata } from "next";
import Link from "next/link";
import { Bus, MapPin, Users, Shield } from "lucide-react";

export const metadata: Metadata = {
  title: "About",
  description:
    "Shuttle Office builds commute infrastructure for modern teams — reliable routes, real-time tracking, and seat reservations across 14 cities.",
};

const VALUES = [
  {
    icon: MapPin,
    title: "Route reliability",
    description:
      "Every route we publish runs on time, tracked in real time. Commuters plan around our schedule, so we treat punctuality as infrastructure.",
  },
  {
    icon: Users,
    title: "Team-first design",
    description:
      "We work directly with operations managers to shape routes around actual team schedules — not the other way around.",
  },
  {
    icon: Shield,
    title: "Transparent operations",
    description:
      "Live seat availability, actual arrival data, and no hidden fees. You see what we see.",
  },
];

const MILESTONES = [
  { year: "2022", event: "Founded in Bangalore with 3 pilot routes" },
  { year: "2023", event: "Expanded to 6 cities, onboarded 20 partner companies" },
  { year: "2024", event: "Launched real-time seat reservations and live tracking" },
  { year: "2025", event: "Operating 127 active routes across 14 cities" },
];

export default function AboutPage() {
  return (
    <>
      {/* ── Hero ── */}
      <section className="mx-auto max-w-7xl px-6 py-20 md:py-28">
        <div className="grid items-start gap-16 md:grid-cols-[1fr_380px]">
          <div>
            <p className="mb-4 font-mono text-[10px] uppercase tracking-widest text-on-surface-variant">
              About Shuttle Office
            </p>
            <h1 className="text-4xl font-black tracking-tight text-on-surface md:text-5xl leading-[1.1]">
              We build commute
              <br />
              <span className="text-brand-600">infrastructure.</span>
            </h1>
            <p className="mt-6 max-w-lg text-lg leading-relaxed text-on-surface-variant">
              Shuttle Office connects employees to their workplaces through
              managed shuttle networks. We handle the routes, the schedules, and
              the seats — so operations teams can stop worrying about how people
              get to the office.
            </p>
          </div>

          {/* Stats card */}
          <div className="rounded-2xl border border-[#c7c4d8]/15 bg-surface-container-lowest p-8">
            <p className="mb-6 font-mono text-[10px] uppercase tracking-widest text-on-surface-variant">
              By the numbers
            </p>
            <div className="space-y-6">
              {[
                { value: "14", label: "Cities" },
                { value: "127", label: "Active routes" },
                { value: "43", label: "Partner companies" },
                { value: "18.4k", label: "Rides this month" },
              ].map((stat) => (
                <div
                  key={stat.label}
                  className="flex items-baseline justify-between border-b border-[#c7c4d8]/15 pb-4 last:border-0 last:pb-0"
                >
                  <span className="font-mono text-2xl font-bold tabular-nums text-on-surface">
                    {stat.value}
                  </span>
                  <span className="font-mono text-[10px] uppercase tracking-wide text-on-surface-variant">
                    {stat.label}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ── Values ── */}
      <section className="bg-surface-container-low py-20">
        <div className="mx-auto max-w-7xl px-6">
          <div className="grid gap-16 md:grid-cols-2 md:items-start">
            <div>
              <p className="mb-4 font-mono text-[10px] uppercase tracking-widest text-on-surface-variant">
                What drives us
              </p>
              <h2 className="text-3xl font-black tracking-tight text-on-surface">
                Built on three commitments
              </h2>
              <p className="mt-4 max-w-sm leading-relaxed text-on-surface-variant">
                These aren&apos;t aspirations. They&apos;re constraints we ship against
                every day.
              </p>
            </div>

            <div className="divide-y divide-[#c7c4d8]/20">
              {VALUES.map((value) => {
                const Icon = value.icon;
                return (
                  <div
                    key={value.title}
                    className="flex items-start gap-5 py-6 first:pt-0 last:pb-0"
                  >
                    <div className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-brand-600/10">
                      <Icon className="h-4 w-4 text-brand-600" />
                    </div>
                    <div>
                      <h3 className="font-bold text-on-surface">{value.title}</h3>
                      <p className="mt-1 text-sm leading-relaxed text-on-surface-variant">
                        {value.description}
                      </p>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </section>

      {/* ── Timeline ── */}
      <section className="mx-auto max-w-7xl px-6 py-20">
        <p className="mb-4 font-mono text-[10px] uppercase tracking-widest text-on-surface-variant">
          Our journey
        </p>
        <h2 className="mb-12 text-3xl font-black tracking-tight text-on-surface">
          From 3 routes to 127
        </h2>
        <div className="grid gap-6 md:grid-cols-2">
          {MILESTONES.map((m) => (
            <div
              key={m.year}
              className="flex items-start gap-6 rounded-2xl border border-[#c7c4d8]/15 bg-surface-container-lowest p-6"
            >
              <span className="font-mono text-3xl font-black tabular-nums text-brand-600/20">
                {m.year}
              </span>
              <p className="pt-2 leading-relaxed text-on-surface-variant">
                {m.event}
              </p>
            </div>
          ))}
        </div>
      </section>

      {/* ── CTA ── */}
      <section className="bg-surface-container-low py-16">
        <div className="mx-auto max-w-7xl px-6 text-center">
          <h2 className="text-2xl font-black tracking-tight text-on-surface">
            Want to bring Shuttle Office to your team?
          </h2>
          <p className="mx-auto mt-3 max-w-md text-on-surface-variant">
            We partner with companies of all sizes to build commute networks that
            actually work.
          </p>
          <Link
            href="/contact"
            className="mt-8 inline-flex items-center gap-2 rounded-lg bg-brand-600 px-6 py-3 font-mono text-sm font-bold uppercase tracking-wider text-white transition-all hover:opacity-90 active:translate-y-px active:scale-[0.99]"
          >
            Get in touch
          </Link>
        </div>
      </section>
    </>
  );
}

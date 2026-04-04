import type { Metadata } from "next";
import { Mail, MapPin, Clock } from "lucide-react";

export const metadata: Metadata = {
  title: "Contact",
  description:
    "Reach the Shuttle Office team — partnerships, support, or general inquiries.",
};

const CONTACT_CHANNELS = [
  {
    icon: Mail,
    label: "Email",
    value: "hello@shuttleoffice.in",
    href: "mailto:hello@shuttleoffice.in",
    description: "For partnerships, support, or general questions",
  },
  {
    icon: MapPin,
    label: "Office",
    value: "Bangalore, India",
    href: null,
    description: "HSR Layout, Sector 1",
  },
  {
    icon: Clock,
    label: "Hours",
    value: "Mon — Fri, 9 am — 6 pm IST",
    href: null,
    description: "We respond within one business day",
  },
];

const INQUIRY_TYPES = [
  {
    title: "Company partnerships",
    description:
      "Want to add shuttle routes for your employees? We work with teams of 50 or more to design commute networks around your office locations.",
    cta: "hello@shuttleoffice.in",
  },
  {
    title: "Route suggestions",
    description:
      "Commuting to an area we don't cover yet? Let us know — we prioritize new routes based on demand and feasibility.",
    cta: "routes@shuttleoffice.in",
  },
  {
    title: "Technical support",
    description:
      "Having trouble with bookings, seat reservations, or your account? Our support team can help.",
    cta: "support@shuttleoffice.in",
  },
];

export default function ContactPage() {
  return (
    <>
      {/* ── Hero ── */}
      <section className="mx-auto max-w-7xl px-6 py-20 md:py-28">
        <div className="grid items-start gap-16 md:grid-cols-[1fr_340px]">
          <div>
            <p className="mb-4 font-mono text-[10px] uppercase tracking-widest text-on-surface-variant">
              Contact
            </p>
            <h1 className="text-4xl font-black tracking-tight text-on-surface md:text-5xl leading-[1.1]">
              Talk to a
              <br />
              <span className="text-brand-600">real person.</span>
            </h1>
            <p className="mt-6 max-w-lg text-lg leading-relaxed text-on-surface-variant">
              No chatbots, no ticket queues. Reach the team that builds and
              operates Shuttle Office directly.
            </p>
          </div>

          {/* Contact card */}
          <div className="rounded-2xl border border-[#c7c4d8]/15 bg-surface-container-lowest p-8">
            <p className="mb-6 font-mono text-[10px] uppercase tracking-widest text-on-surface-variant">
              Reach us
            </p>
            <div className="space-y-6">
              {CONTACT_CHANNELS.map((channel) => {
                const Icon = channel.icon;
                return (
                  <div key={channel.label} className="flex items-start gap-4">
                    <div className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-brand-600/10">
                      <Icon className="h-4 w-4 text-brand-600" />
                    </div>
                    <div>
                      <p className="font-mono text-[10px] uppercase tracking-wide text-on-surface-variant">
                        {channel.label}
                      </p>
                      {channel.href ? (
                        <a
                          href={channel.href}
                          className="font-bold text-on-surface transition-colors hover:text-brand-600"
                        >
                          {channel.value}
                        </a>
                      ) : (
                        <p className="font-bold text-on-surface">
                          {channel.value}
                        </p>
                      )}
                      <p className="mt-0.5 text-sm text-on-surface-variant">
                        {channel.description}
                      </p>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </section>

      {/* ── Inquiry types ── */}
      <section className="bg-surface-container-low py-20">
        <div className="mx-auto max-w-7xl px-6">
          <p className="mb-4 font-mono text-[10px] uppercase tracking-widest text-on-surface-variant">
            How can we help
          </p>
          <h2 className="mb-12 text-3xl font-black tracking-tight text-on-surface">
            Pick the right channel
          </h2>

          <div className="grid gap-6 md:grid-cols-2">
            {INQUIRY_TYPES.map((inquiry, i) => (
              <div
                key={inquiry.title}
                className={`rounded-2xl border border-[#c7c4d8]/15 bg-surface-container-lowest p-8 ${
                  i === 0 ? "md:col-span-2" : ""
                }`}
              >
                <div className="flex items-start gap-6">
                  <span className="font-mono text-3xl font-black tabular-nums text-brand-600/20">
                    0{i + 1}
                  </span>
                  <div className="pt-1">
                    <h3 className="text-lg font-bold text-on-surface">
                      {inquiry.title}
                    </h3>
                    <p className="mt-2 max-w-lg leading-relaxed text-on-surface-variant">
                      {inquiry.description}
                    </p>
                    <a
                      href={`mailto:${inquiry.cta}`}
                      className="mt-4 inline-block font-mono text-sm font-bold text-brand-600 transition-colors hover:text-brand-700"
                    >
                      {inquiry.cta}
                    </a>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}

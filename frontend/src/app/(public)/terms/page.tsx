import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Terms of Service",
  description:
    "Terms and conditions governing your use of the Shuttle Office platform.",
};

const LAST_UPDATED = "1 April 2025";

const SECTIONS = [
  {
    title: "Acceptance of terms",
    content: [
      "By accessing or using Shuttle Office, you agree to be bound by these terms. If you are using the platform on behalf of a company, you represent that you have authority to bind that organisation to these terms.",
      "We may modify these terms at any time. Continued use of the platform after changes constitutes acceptance. Material changes are communicated via email at least 14 days in advance.",
    ],
  },
  {
    title: "Account responsibilities",
    content: [
      "You are responsible for maintaining the security of your account credentials. Do not share your password or allow others to access your account.",
      "You must provide accurate registration information. Accounts created with false identities or on behalf of unauthorised third parties may be suspended without notice.",
    ],
  },
  {
    title: "Seat reservations and bookings",
    content: [
      "A confirmed booking reserves your seat on the specified departure. Seats are held until the scheduled departure time — after which unclaimed seats may be released.",
      "Repeated no-shows (3 or more in a 30-day period) may result in temporary booking restrictions. This helps maintain availability for all commuters.",
      "Shuttle Office does not guarantee departure times. Schedules are estimates and may be affected by traffic, weather, or operational issues.",
    ],
  },
  {
    title: "Company accounts",
    content: [
      "Company administrators may manage employee access, view aggregated usage reports, and configure route preferences for their organisation.",
      "Company accounts are billed according to the terms of their service agreement. Individual employees using company-provisioned access are also bound by these terms.",
    ],
  },
  {
    title: "Acceptable use",
    content: [
      "You may not use Shuttle Office to reserve seats you do not intend to use, create automated booking scripts, or otherwise interfere with fair access to the platform.",
      "Abusive behaviour toward shuttle operators, drivers, or fellow commuters — whether on the platform or on a shuttle — may result in account suspension.",
    ],
  },
  {
    title: "Intellectual property",
    content: [
      "All content on the Shuttle Office platform — including route data, schedule information, interface design, and branding — is owned by Shuttle Office or its licensors.",
      "You may not scrape, reproduce, or redistribute platform content without prior written consent.",
    ],
  },
  {
    title: "Limitation of liability",
    content: [
      "Shuttle Office provides a booking and information platform. We are not a transportation provider. Shuttle operations are managed by partner companies who bear responsibility for vehicle safety and compliance.",
      "To the maximum extent permitted by law, Shuttle Office is not liable for delays, cancellations, or incidents occurring during transit.",
    ],
  },
  {
    title: "Termination",
    content: [
      "You may close your account at any time by contacting support@shuttleoffice.in. Active bookings will be cancelled upon account closure.",
      "We may suspend or terminate accounts that violate these terms, with or without prior notice depending on severity.",
    ],
  },
  {
    title: "Governing law",
    content: [
      "These terms are governed by the laws of India. Any disputes arising from your use of Shuttle Office will be subject to the exclusive jurisdiction of courts in Bangalore, Karnataka.",
    ],
  },
];

export default function TermsPage() {
  return (
    <section className="mx-auto max-w-7xl px-6 py-20 md:py-28">
      <div className="grid gap-16 md:grid-cols-[280px_1fr] md:items-start">
        {/* Sidebar */}
        <div className="md:sticky md:top-24">
          <p className="mb-4 font-mono text-[10px] uppercase tracking-widest text-on-surface-variant">
            Legal
          </p>
          <h1 className="text-3xl font-black tracking-tight text-on-surface md:text-4xl leading-[1.1]">
            Terms of
            <br />
            <span className="text-brand-600">Service</span>
          </h1>
          <p className="mt-4 text-sm leading-relaxed text-on-surface-variant">
            Last updated {LAST_UPDATED}
          </p>
          <p className="mt-6 text-sm leading-relaxed text-on-surface-variant">
            Questions about these terms?
            <br />
            <a
              href="mailto:legal@shuttleoffice.in"
              className="font-bold text-brand-600 transition-colors hover:text-brand-700"
            >
              legal@shuttleoffice.in
            </a>
          </p>
        </div>

        {/* Content */}
        <div className="divide-y divide-[#c7c4d8]/20">
          {SECTIONS.map((section, i) => (
            <div key={section.title} className="py-8 first:pt-0 last:pb-0">
              <div className="flex items-start gap-6">
                <span className="hidden font-mono text-2xl font-black tabular-nums text-brand-600/15 md:block">
                  0{i + 1}
                </span>
                <div>
                  <h2 className="text-lg font-bold text-on-surface">
                    {section.title}
                  </h2>
                  <div className="mt-3 space-y-3">
                    {section.content.map((paragraph, j) => (
                      <p
                        key={j}
                        className="max-w-prose leading-relaxed text-on-surface-variant"
                      >
                        {paragraph}
                      </p>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

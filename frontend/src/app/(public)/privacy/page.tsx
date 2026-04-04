import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "How Shuttle Office collects, uses, and protects your personal information.",
};

const LAST_UPDATED = "1 April 2025";

const SECTIONS = [
  {
    title: "Information we collect",
    content: [
      "When you create an account, we collect your name, email address, and company affiliation. If you book a seat, we store your route preferences and booking history to improve recommendations.",
      "We collect device and browser metadata (IP address, user agent, screen resolution) for analytics and security monitoring. We do not track your location outside of active route sessions.",
    ],
  },
  {
    title: "How we use your data",
    content: [
      "Your personal data powers core product functionality: account authentication, seat reservations, schedule personalisation, and route notifications.",
      "We aggregate anonymised usage data to improve route planning, predict demand, and optimise departure times. This data cannot be traced back to individual users.",
      "We do not sell, rent, or trade your personal information to third parties. We do not serve ads.",
    ],
  },
  {
    title: "Data storage and security",
    content: [
      "All user data is stored on encrypted servers hosted within India. Passwords are hashed using bcrypt and never stored in plain text.",
      "Session tokens are transmitted via HTTP-only cookies over TLS. API access is scoped to role-based permissions — employees, company admins, and platform operators each have distinct access levels.",
    ],
  },
  {
    title: "Cookies",
    content: [
      "We use strictly necessary cookies for authentication and session management. We do not use third-party advertising or tracking cookies.",
      "A single analytics cookie may be set to measure page visits and feature usage. This cookie contains no personally identifiable information and can be blocked without affecting functionality.",
    ],
  },
  {
    title: "Your rights",
    content: [
      "You may request a copy of all data we hold about you, ask us to correct inaccuracies, or delete your account entirely. Deletion requests are processed within 7 business days.",
      "To exercise any of these rights, email privacy@shuttleoffice.in with your registered email address.",
    ],
  },
  {
    title: "Data retention",
    content: [
      "Active accounts retain data indefinitely for product functionality. If you delete your account, personal data is purged within 30 days. Anonymised analytics data may be retained longer.",
      "Booking history older than 12 months is automatically anonymised and cannot be linked to your account.",
    ],
  },
  {
    title: "Changes to this policy",
    content: [
      "We may update this policy as our product evolves. Material changes will be communicated via email to registered users at least 14 days before they take effect.",
    ],
  },
];

export default function PrivacyPage() {
  return (
    <section className="mx-auto max-w-7xl px-6 py-20 md:py-28">
      <div className="grid gap-16 md:grid-cols-[280px_1fr] md:items-start">
        {/* Sidebar */}
        <div className="md:sticky md:top-24">
          <p className="mb-4 font-mono text-[10px] uppercase tracking-widest text-on-surface-variant">
            Legal
          </p>
          <h1 className="text-3xl font-black tracking-tight text-on-surface md:text-4xl leading-[1.1]">
            Privacy
            <br />
            <span className="text-brand-600">Policy</span>
          </h1>
          <p className="mt-4 text-sm leading-relaxed text-on-surface-variant">
            Last updated {LAST_UPDATED}
          </p>
          <p className="mt-6 text-sm leading-relaxed text-on-surface-variant">
            Questions about your data?
            <br />
            <a
              href="mailto:privacy@shuttleoffice.in"
              className="font-bold text-brand-600 transition-colors hover:text-brand-700"
            >
              privacy@shuttleoffice.in
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

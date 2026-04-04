import Link from "next/link";
import { Bus } from "lucide-react";

const PRODUCT_LINKS = [
  { label: "Schedules", href: "/schedules" },
  { label: "Companies", href: "/companies" },
  { label: "Get started", href: "/register" },
];

const COMPANY_LINKS = [
  { label: "About", href: "/about" },
  { label: "Contact", href: "/contact" },
];

const LEGAL_LINKS = [
  { label: "Privacy", href: "/privacy" },
  { label: "Terms", href: "/terms" },
];

export function Footer() {
  return (
    <footer className="border-t border-[#c7c4d8]/15 bg-surface">
      <div className="mx-auto max-w-7xl px-6 py-12">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-4 mb-12">
          {/* Brand */}
          <div className="col-span-2 md:col-span-1">
            <Link href="/" className="mb-4 flex items-center gap-2">
              <div className="flex h-6 w-6 items-center justify-center rounded-md bg-brand-600">
                <Bus className="h-3.5 w-3.5 text-white" />
              </div>
              <span className="text-sm font-black uppercase tracking-tighter text-brand-600">
                Shuttle Office
              </span>
            </Link>
            <p className="text-sm leading-relaxed text-on-surface-variant">
              Office commuting infrastructure for modern teams.
            </p>
          </div>

          {/* Product */}
          <div>
            <h4 className="mb-4 font-mono text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">
              Product
            </h4>
            <ul className="space-y-3">
              {PRODUCT_LINKS.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-sm text-on-surface-variant transition-colors hover:text-on-surface"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Company */}
          <div>
            <h4 className="mb-4 font-mono text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">
              Company
            </h4>
            <ul className="space-y-3">
              {COMPANY_LINKS.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-sm text-on-surface-variant transition-colors hover:text-on-surface"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Legal */}
          <div>
            <h4 className="mb-4 font-mono text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">
              Legal
            </h4>
            <ul className="space-y-3">
              {LEGAL_LINKS.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-sm text-on-surface-variant transition-colors hover:text-on-surface"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </div>

        {/* Bottom bar */}
        <div className="flex flex-col items-start gap-4 border-t border-[#c7c4d8]/15 pt-8 md:flex-row md:items-center md:justify-between">
          <p className="font-mono text-[11px] text-on-surface-variant">
            © {new Date().getFullYear()} Shuttle Office. All rights reserved.
          </p>
          <div className="flex items-center gap-1.5">
            <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-accent-500" />
            <span className="font-mono text-[11px] text-on-surface-variant">
              All systems operational
            </span>
          </div>
        </div>
      </div>
    </footer>
  );
}

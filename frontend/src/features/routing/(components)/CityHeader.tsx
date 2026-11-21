"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChevronLeft } from "lucide-react";
import { cn } from "@/lib/utils";
import { useCity } from "../(queries)/queries";

/** City name and the Stops / Distances / Fares tabs shared by the city's routing pages. */
export function CityHeader({ cityUid }: { cityUid: string }) {
  const pathname = usePathname();
  const { data } = useCity(cityUid);
  const base = `/admin/routing/${encodeURIComponent(cityUid)}`;

  const tabs = [
    { label: "Stops", href: base },
    { label: "Distances", href: `${base}/distances` },
    { label: "Fares", href: `${base}/fares` },
  ];

  return (
    <div className="space-y-4">
      <div>
        <Link
          href="/admin/routing"
          className="inline-flex items-center gap-1 font-mono text-[11px] uppercase tracking-wider text-on-surface-variant hover:text-on-surface"
        >
          <ChevronLeft className="h-3 w-3" />
          All cities
        </Link>
        <h1 className="mt-1 text-2xl font-bold text-foreground">{data?.data.attributes.name ?? "City"}</h1>
      </div>
      <nav className="flex gap-1 border-b border-[#c7c4d8]/30" aria-label="City routing sections">
        {tabs.map((tab) => (
          <Link
            key={tab.href}
            href={tab.href}
            aria-current={pathname === tab.href ? "page" : undefined}
            className={cn(
              "-mb-px border-b-2 px-4 py-2 font-mono text-xs font-medium uppercase tracking-wide transition-colors",
              pathname === tab.href
                ? "border-brand-600 text-brand-700"
                : "border-transparent text-on-surface-variant hover:text-on-surface"
            )}
          >
            {tab.label}
          </Link>
        ))}
      </nav>
    </div>
  );
}

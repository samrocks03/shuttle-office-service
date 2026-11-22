"use client";

import Link from "next/link";
import { MapPin } from "lucide-react";
import { bffErrorMessage } from "@/features/reservations/(queries)/queries";
import { useCities } from "../(queries)/queries";

export function CityList() {
  const { data, isLoading, isError, error } = useCities();

  if (isLoading) {
    return <div className="h-24 animate-pulse rounded-xl bg-surface-container-low" />;
  }
  if (isError) {
    return <p className="text-sm text-red-600">{bffErrorMessage(error)}</p>;
  }

  const cities = data?.data ?? [];
  if (cities.length === 0) {
    return <p className="text-sm text-on-surface-variant">No cities yet.</p>;
  }

  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3" data-testid="city-list">
      {cities.map(({ attributes: city }) => (
        <Link
          key={city.uid}
          href={`/admin/routing/${encodeURIComponent(city.uid)}`}
          className="flex items-start gap-4 rounded-xl border border-transparent bg-surface-container-lowest px-5 py-4 transition-all hover:border-[#c7c4d8]/30 hover:shadow-sm"
        >
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-brand-600/10">
            <MapPin className="h-4 w-4 text-brand-600" />
          </div>
          <div className="min-w-0">
            <div className="font-medium text-on-surface">{city.name}</div>
            <div className="mt-1 font-mono text-[11px] text-on-surface-variant">
              {city.stops_count} stops · {city.currency} · {city.distance_provider}
            </div>
          </div>
        </Link>
      ))}
    </div>
  );
}

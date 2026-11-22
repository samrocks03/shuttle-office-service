"use client";

import { bffErrorMessage } from "@/features/reservations/(queries)/queries";
import { useStops } from "../(queries)/queries";

export function StopsTable({ cityUid }: { cityUid: string }) {
  const { data, isLoading, isError, error } = useStops(cityUid);

  if (isLoading) return <div className="h-40 animate-pulse rounded-xl bg-surface-container-low" />;
  if (isError) return <p className="text-sm text-red-600">{bffErrorMessage(error)}</p>;

  const stops = data?.data ?? [];
  if (stops.length === 0) return <p className="text-sm text-on-surface-variant">This city has no stops yet.</p>;

  return (
    <div className="overflow-x-auto rounded-xl bg-surface-container-lowest">
      <table className="w-full text-left text-sm" data-testid="stops-table">
        <thead>
          <tr className="border-b border-[#c7c4d8]/30 font-mono text-[10px] uppercase tracking-wider text-on-surface-variant">
            <th className="px-4 py-3">Name</th>
            <th className="px-4 py-3">Kind</th>
            <th className="px-4 py-3">Latitude</th>
            <th className="px-4 py-3">Longitude</th>
            <th className="px-4 py-3">Status</th>
          </tr>
        </thead>
        <tbody>
          {stops.map(({ attributes: stop }) => (
            <tr key={stop.uid} className="border-b border-[#c7c4d8]/15 last:border-0">
              <td className="px-4 py-2.5 font-medium text-on-surface">{stop.name}</td>
              <td className="px-4 py-2.5 capitalize text-on-surface-variant">{stop.kind}</td>
              <td className="px-4 py-2.5 font-mono tabular-nums text-on-surface-variant">{stop.latitude.toFixed(5)}</td>
              <td className="px-4 py-2.5 font-mono tabular-nums text-on-surface-variant">{stop.longitude.toFixed(5)}</td>
              <td className="px-4 py-2.5">
                <span
                  className={
                    stop.active
                      ? "rounded-full bg-accent-500/10 px-2 py-0.5 font-mono text-[10px] font-bold uppercase tracking-wider text-accent-700"
                      : "rounded-full bg-surface-container-low px-2 py-0.5 font-mono text-[10px] font-bold uppercase tracking-wider text-on-surface-variant"
                  }
                >
                  {stop.active ? "Active" : "Inactive"}
                </span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

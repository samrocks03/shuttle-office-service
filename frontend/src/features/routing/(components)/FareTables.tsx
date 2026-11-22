"use client";

import { bffErrorMessage } from "@/features/reservations/(queries)/queries";
import { formatMoney } from "@/shared/lib/money";
import { useFareTables } from "../(queries)/queries";
import { formatKm, SERVICE_CLASS_LABELS } from "./format";

function FareTableCard({ table }: { table: IFareTableAttributes }) {
  const lastSlab = table.slabs[table.slabs.length - 1];

  return (
    <section
      className="rounded-xl bg-surface-container-lowest p-5"
      data-testid="fare-table"
      aria-label={`${SERVICE_CLASS_LABELS[table.service_class] ?? table.service_class} fare table`}
    >
      <div className="flex flex-wrap items-center gap-2">
        <h2 className="text-lg font-semibold text-on-surface">
          {SERVICE_CLASS_LABELS[table.service_class] ?? table.service_class}
        </h2>
        <span className="rounded bg-surface-container-low px-1.5 py-0.5 font-mono text-[10px] font-bold uppercase tracking-wider text-on-surface-variant">
          {table.policy}
        </span>
        <span
          className={
            table.active
              ? "rounded-full bg-accent-500/10 px-2 py-0.5 font-mono text-[10px] font-bold uppercase tracking-wider text-accent-700"
              : "rounded-full bg-surface-container-low px-2 py-0.5 font-mono text-[10px] font-bold uppercase tracking-wider text-on-surface-variant"
          }
        >
          {table.active ? "Active" : "Inactive"}
        </span>
        <span className="font-mono text-[11px] text-on-surface-variant">
          from {table.effective_from} · {table.currency}
        </span>
      </div>

      {table.slabs.length === 0 ? (
        <p className="mt-3 text-sm text-on-surface-variant">No slabs.</p>
      ) : (
        <table className="mt-4 w-full max-w-md text-left text-sm">
          <thead>
            <tr className="border-b border-[#c7c4d8]/30 font-mono text-[10px] uppercase tracking-wider text-on-surface-variant">
              <th className="py-2 pr-4">Up to</th>
              <th className="py-2 text-right">Fare</th>
            </tr>
          </thead>
          <tbody>
            {table.slabs.map((slab) => (
              <tr key={slab.up_to_km} className="border-b border-[#c7c4d8]/15 last:border-0">
                <td className="py-1.5 pr-4 font-mono tabular-nums text-on-surface-variant">{formatKm(slab.up_to_km)} km</td>
                <td className="py-1.5 text-right font-mono font-semibold tabular-nums text-on-surface">
                  {formatMoney(slab.amount_minor, table.currency)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {lastSlab && table.step_km != null && table.step_amount_minor != null && (
        <p className="mt-3 text-xs text-on-surface-variant">
          Beyond {formatKm(lastSlab.up_to_km)} km: add {formatMoney(table.step_amount_minor, table.currency)} for every
          started {formatKm(table.step_km)} km.
        </p>
      )}
    </section>
  );
}

/** Read-only fare tables of a city. Prices change by adding a new table with a later effective date. */
export function FareTables({ cityUid }: { cityUid: string }) {
  const { data, isLoading, isError, error } = useFareTables(cityUid);

  if (isLoading) return <div className="h-40 animate-pulse rounded-xl bg-surface-container-low" />;
  if (isError) return <p className="text-sm text-red-600">{bffErrorMessage(error)}</p>;

  const tables = data?.data ?? [];
  if (tables.length === 0) return <p className="text-sm text-on-surface-variant">This city has no fare tables.</p>;

  return (
    <div className="space-y-4">
      {tables.map(({ attributes }) => (
        <FareTableCard key={attributes.uid} table={attributes} />
      ))}
    </div>
  );
}

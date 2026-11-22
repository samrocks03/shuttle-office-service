"use client";

import { useMemo, useState } from "react";
import { AlertTriangle } from "lucide-react";
import { cn } from "@/lib/utils";
import { bffErrorMessage } from "@/features/reservations/(queries)/queries";
import { useSetOverride, useStopDistances } from "../(queries)/queries";
import { formatKm } from "./format";

// Mirrors StopDistance::MAX_OVERRIDE_KM on the server, which has the final say.
const MAX_OVERRIDE_KM = 500;

/** The km typed into the form, or an error message when it is not a valid override. */
function parseKm(text: string): { km: number } | { error: string } {
  const km = Number(text);
  if (text.trim() === "" || !Number.isFinite(km) || km <= 0 || km > MAX_OVERRIDE_KM) {
    return { error: `Enter a distance above 0 and up to ${MAX_OVERRIDE_KM} km.` };
  }
  return { km };
}

function DistanceRow({ cityUid, row }: { cityUid: string; row: IStopDistanceAttributes }) {
  const mutation = useSetOverride(cityUid, row.uid);
  const [km, setKm] = useState(row.override_km == null ? "" : String(row.override_km));
  const [reason, setReason] = useState(row.override_reason ?? "");
  const [formError, setFormError] = useState<string | null>(null);

  const save = (event: React.FormEvent) => {
    event.preventDefault();
    const parsed = parseKm(km);
    if ("error" in parsed) {
      setFormError(parsed.error);
      return;
    }
    setFormError(null);
    mutation.mutate({ override_km: parsed.km, override_reason: reason.trim() || null });
  };

  const clear = () => {
    setFormError(null);
    mutation.mutate(
      { override_km: null },
      {
        onSuccess: () => {
          setKm("");
          setReason("");
        },
      }
    );
  };

  const error = formError ?? (mutation.isError ? bffErrorMessage(mutation.error) : null);
  const inputId = `override-km-${row.uid}`;

  return (
    <tr
      data-testid="distance-row"
      data-unrouted={row.unrouted}
      className={cn(
        "border-b border-[#c7c4d8]/15 align-top last:border-0",
        row.unrouted && "bg-amber-500/10 shadow-[inset_3px_0_0_0_theme(colors.amber.500)]"
      )}
    >
      <td className="px-4 py-3 text-on-surface">{row.from_stop.name}</td>
      <td className="px-4 py-3 text-on-surface">{row.to_stop.name}</td>
      <td className="px-4 py-3 font-mono tabular-nums text-on-surface-variant">{formatKm(row.computed_km)}</td>
      <td className="px-4 py-3 font-mono tabular-nums text-on-surface-variant">
        {formatKm(row.override_km)}
        {row.override_km != null && row.overridden_by_name && (
          <div className="mt-0.5 font-sans text-[11px] text-on-surface-variant">by {row.overridden_by_name}</div>
        )}
      </td>
      <td className="px-4 py-3 font-mono font-semibold tabular-nums text-on-surface">
        {row.unrouted ? (
          <span className="inline-flex items-center gap-1 text-amber-700">
            <AlertTriangle className="h-3.5 w-3.5" />
            Unrouted
          </span>
        ) : (
          formatKm(row.effective_km)
        )}
      </td>
      <td className="px-4 py-3">
        <form onSubmit={save} className="flex flex-wrap items-start gap-2" aria-label={`Override ${row.from_stop.name} to ${row.to_stop.name}`}>
          <label htmlFor={inputId} className="sr-only">
            Override km for {row.from_stop.name} to {row.to_stop.name}
          </label>
          <input
            id={inputId}
            type="number"
            inputMode="decimal"
            step="0.1"
            min="0"
            max={MAX_OVERRIDE_KM}
            placeholder="km"
            value={km}
            onChange={(e) => setKm(e.target.value)}
            aria-invalid={error != null}
            className="h-8 w-20 rounded-lg border border-input bg-transparent px-2 font-mono text-sm tabular-nums outline-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50"
          />
          <input
            type="text"
            placeholder="Reason"
            aria-label={`Reason for ${row.from_stop.name} to ${row.to_stop.name}`}
            maxLength={255}
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            className="h-8 w-40 rounded-lg border border-input bg-transparent px-2 text-sm outline-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50"
          />
          <button
            type="submit"
            disabled={mutation.isPending}
            className="h-8 rounded-lg bg-brand-600 px-3 font-mono text-[10px] font-bold uppercase tracking-wider text-white transition-all hover:bg-brand-700 disabled:opacity-50"
          >
            {mutation.isPending ? "Saving..." : "Save"}
          </button>
          {row.override_km != null && (
            <button
              type="button"
              onClick={clear}
              disabled={mutation.isPending}
              className="h-8 rounded-lg px-3 font-mono text-[10px] font-bold uppercase tracking-wider text-on-surface-variant transition-colors hover:bg-red-500/10 hover:text-red-600 disabled:opacity-50"
            >
              Clear
            </button>
          )}
          {error && (
            <p role="alert" className="basis-full text-xs text-red-600">
              {error}
            </p>
          )}
        </form>
      </td>
    </tr>
  );
}

export function DistancesTable({ cityUid }: { cityUid: string }) {
  const { data, isLoading, isError, error } = useStopDistances(cityUid);
  const [unroutedOnly, setUnroutedOnly] = useState(false);

  const rows = useMemo(
    () =>
      (data?.data ?? [])
        .map((resource) => resource.attributes)
        .sort(
          (a, b) => a.from_stop.name.localeCompare(b.from_stop.name) || a.to_stop.name.localeCompare(b.to_stop.name)
        ),
    [data]
  );

  if (isLoading) return <div className="h-40 animate-pulse rounded-xl bg-surface-container-low" />;
  if (isError) return <p className="text-sm text-red-600">{bffErrorMessage(error)}</p>;
  if (rows.length === 0) {
    return <p className="text-sm text-on-surface-variant">No distances yet. They are computed once the city has pickups and offices.</p>;
  }

  const unrouted = rows.filter((row) => row.unrouted).length;
  const shown = unroutedOnly ? rows.filter((row) => row.unrouted) : rows;
  const total = data?.meta.total_count ?? rows.length;

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-on-surface-variant" data-testid="distance-summary">
          {total} pairs ·{" "}
          <span className={cn(unrouted > 0 && "font-semibold text-amber-700")}>{unrouted} unrouted</span>
          {total > rows.length && ` · showing the first ${rows.length}`}
        </p>
        <label className="flex items-center gap-2 text-sm text-on-surface-variant">
          <input type="checkbox" checked={unroutedOnly} onChange={(e) => setUnroutedOnly(e.target.checked)} />
          Unrouted only
        </label>
      </div>

      <div className="overflow-x-auto rounded-xl bg-surface-container-lowest">
        <table className="w-full text-left text-sm" data-testid="distances-table">
          <thead>
            <tr className="border-b border-[#c7c4d8]/30 font-mono text-[10px] uppercase tracking-wider text-on-surface-variant">
              <th className="px-4 py-3">From</th>
              <th className="px-4 py-3">To</th>
              <th className="px-4 py-3">Computed km</th>
              <th className="px-4 py-3">Override km</th>
              <th className="px-4 py-3">Effective km</th>
              <th className="px-4 py-3">Set override</th>
            </tr>
          </thead>
          <tbody>
            {shown.map((row) => (
              <DistanceRow key={row.uid} cityUid={cityUid} row={row} />
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

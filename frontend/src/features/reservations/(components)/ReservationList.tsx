"use client";

import { useState } from "react";
import { MapPin, Clock, Building2, X, ChevronLeft, ChevronRight, Ticket } from "lucide-react";
import { cn } from "@/lib/utils";
import { useReservations, useCancelReservation } from "../(queries)/queries";

function ReservationCard({ reservation }: { reservation: IReservationResource }) {
  const a = reservation.attributes;
  const cancel = useCancelReservation();
  const [confirming, setConfirming] = useState(false);

  return (
    <div className="flex items-start gap-4 rounded-xl border border-transparent bg-surface-container-lowest px-5 py-4 transition-all hover:border-[#c7c4d8]/20 hover:shadow-sm">
      {/* Icon */}
      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-brand-600/10">
        <Ticket className="h-4 w-4 text-brand-600" />
      </div>

      {/* Details */}
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <span className="font-medium text-on-surface">{a.schedule.start_point}</span>
          <span className="rounded bg-surface-container-low px-1.5 py-0.5 font-mono text-[10px] font-bold uppercase tracking-wider text-on-surface-variant">
            {a.schedule.date}
          </span>
        </div>

        <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-on-surface-variant">
          <span className="inline-flex items-center gap-1">
            <Clock className="h-3 w-3" />
            <span className="font-mono tabular-nums">
              {a.schedule.departure_time} → {a.schedule.arrival_time}
            </span>
          </span>
          {a.schedule.company_name && (
            <span className="inline-flex items-center gap-1">
              <Building2 className="h-3 w-3" />
              {a.schedule.company_name}
            </span>
          )}
        </div>
      </div>

      {/* Cancel action */}
      <div className="shrink-0">
        {confirming ? (
          <div className="flex items-center gap-2">
            <button
              onClick={() => {
                cancel.mutate(a.uid);
                setConfirming(false);
              }}
              disabled={cancel.isPending}
              className="rounded-lg bg-red-500/10 px-3 py-1.5 font-mono text-[10px] font-bold uppercase tracking-wider text-red-600 transition-colors hover:bg-red-500/20 disabled:opacity-50"
            >
              {cancel.isPending ? "Cancelling..." : "Confirm"}
            </button>
            <button
              onClick={() => setConfirming(false)}
              className="rounded-lg p-1.5 text-on-surface-variant transition-colors hover:bg-surface-container-low"
            >
              <X className="h-3.5 w-3.5" />
            </button>
          </div>
        ) : (
          <button
            onClick={() => setConfirming(true)}
            className="rounded-lg px-3 py-1.5 font-mono text-[10px] font-bold uppercase tracking-wider text-on-surface-variant transition-colors hover:bg-red-500/10 hover:text-red-600"
          >
            Cancel
          </button>
        )}
      </div>
    </div>
  );
}

function SkeletonCard() {
  return (
    <div className="flex items-start gap-4 rounded-xl bg-surface-container-lowest px-5 py-4">
      <div className="h-10 w-10 shrink-0 animate-pulse rounded-lg bg-surface-container-low" />
      <div className="flex-1 space-y-2">
        <div className="h-4 w-48 animate-pulse rounded bg-surface-container-low" />
        <div className="h-3 w-32 animate-pulse rounded bg-surface-container-low" />
      </div>
      <div className="h-7 w-16 animate-pulse rounded-lg bg-surface-container-low" />
    </div>
  );
}

export function ReservationList() {
  const [page, setPage] = useState(1);
  const { data, isLoading, isFetching } = useReservations(page);

  const reservations = data?.data ?? [];
  const meta = data?.meta;

  return (
    <div>
      {/* Header */}
      <div className="mb-6">
        <p className="mb-2 font-mono text-[10px] uppercase tracking-widest text-on-surface-variant">
          My bookings
        </p>
        <h1 className="text-2xl font-black tracking-tight text-on-surface">
          Reservations
        </h1>
        <p className="mt-1 text-sm text-on-surface-variant">
          Your upcoming and past shuttle reservations.
        </p>
      </div>

      {/* List */}
      <div className={cn("space-y-2", isFetching && !isLoading && "opacity-60 transition-opacity")}>
        {isLoading ? (
          Array.from({ length: 4 }).map((_, i) => <SkeletonCard key={i} />)
        ) : reservations.length === 0 ? (
          <div className="flex flex-col items-center justify-center rounded-2xl bg-surface-container-lowest py-16 text-center">
            <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-surface-container-low">
              <Ticket className="h-6 w-6 text-on-surface-variant/40" />
            </div>
            <h3 className="mt-4 font-semibold text-on-surface">No reservations yet</h3>
            <p className="mt-1 max-w-xs text-sm text-on-surface-variant">
              Browse available schedules and reserve your seat to get started.
            </p>
            <a
              href="/schedules"
              className="mt-4 inline-flex rounded-lg bg-brand-600 px-4 py-2 font-mono text-xs font-bold uppercase tracking-wider text-white transition-all hover:opacity-90 active:translate-y-px"
            >
              Browse schedules
            </a>
          </div>
        ) : (
          reservations.map((reservation) => (
            <ReservationCard key={reservation.id} reservation={reservation} />
          ))
        )}
      </div>

      {/* Pagination */}
      {meta && meta.total_pages > 1 && (
        <div className="mt-6 flex items-center justify-between border-t border-[#c7c4d8]/15 pt-4">
          <button
            onClick={() => setPage((p) => p - 1)}
            disabled={meta.current_page <= 1}
            className="inline-flex items-center gap-1 rounded-lg px-3 py-1.5 font-mono text-xs font-semibold text-on-surface-variant transition-colors hover:bg-surface-container-low disabled:opacity-30 disabled:pointer-events-none"
          >
            <ChevronLeft className="h-3.5 w-3.5" />
            Prev
          </button>
          <span className="font-mono text-xs tabular-nums text-on-surface-variant">
            Page {meta.current_page} of {meta.total_pages}
          </span>
          <button
            onClick={() => setPage((p) => p + 1)}
            disabled={meta.current_page >= meta.total_pages}
            className="inline-flex items-center gap-1 rounded-lg px-3 py-1.5 font-mono text-xs font-semibold text-on-surface-variant transition-colors hover:bg-surface-container-low disabled:opacity-30 disabled:pointer-events-none"
          >
            Next
            <ChevronRight className="h-3.5 w-3.5" />
          </button>
        </div>
      )}
    </div>
  );
}

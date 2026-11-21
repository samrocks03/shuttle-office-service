"use client";

import { useState } from "react";
import Link from "next/link";
import { Clock, Building2, X, ChevronLeft, ChevronRight, Ticket, CreditCard } from "lucide-react";
import { cn } from "@/lib/utils";
import { formatMoney } from "@/shared/lib/money";
import { formatFare, minutesLeft, useNow } from "@/features/payments/(components)/format";
import { useReservations, useCancelReservation, bffErrorMessage } from "../(queries)/queries";

const STATUS_BADGES: Record<ReservationStatus, { label: string; className: string }> = {
  pending_payment: { label: "Pending payment", className: "bg-amber-500/10 text-amber-700" },
  confirmed: { label: "Confirmed", className: "bg-accent-500/10 text-accent-700" },
  cancelled: { label: "Cancelled", className: "bg-surface-container-low text-on-surface-variant" },
  expired: { label: "Expired", className: "bg-red-500/10 text-red-700" },
};

function StatusBadge({ status, paid }: { status: ReservationStatus; paid: boolean }) {
  const badge = STATUS_BADGES[status] ?? STATUS_BADGES.confirmed;
  // A confirmed booking with a fare was paid for; a free one is simply confirmed.
  const label = status === "confirmed" && paid ? "Paid" : badge.label;
  return (
    <span
      data-testid="reservation-status"
      className={cn("rounded-full px-2 py-0.5 font-mono text-[10px] font-bold uppercase tracking-wider", badge.className)}
    >
      {label}
    </span>
  );
}

const REFUND_BADGES: Record<string, { label: string; className: string }> = {
  pending: { label: "Refund pending", className: "text-amber-700" },
  succeeded: { label: "Refunded", className: "text-accent-700" },
  failed: { label: "Refund failed", className: "text-red-700" },
};

/** "Refund pending · Rs 35"; any other gateway status is shown as "Refund <status>". */
function RefundNote({ refund, currency }: { refund: IReservationRefund; currency: string }) {
  const badge = REFUND_BADGES[refund.status] ?? {
    label: `Refund ${refund.status.replace(/_/g, " ")}`,
    className: "text-on-surface-variant",
  };
  return (
    <span data-testid="reservation-refund" className={cn("font-mono font-semibold", badge.className)}>
      {badge.label} · {formatMoney(refund.amount_minor, currency)}
    </span>
  );
}

/** Schedule date (YYYY-MM-DD) and departure (HH:MM) as a local time, for the cancel button only. */
function departsAt(schedule: IReservationSchedule) {
  return new Date(`${schedule.date}T${schedule.departure_time}:00`).getTime();
}

function ReservationCard({ reservation, now }: { reservation: IReservationResource; now: number }) {
  const a = reservation.attributes;
  const cancel = useCancelReservation();
  const [confirming, setConfirming] = useState(false);
  const [refundStarted, setRefundStarted] = useState(false);

  const paid = a.fare != null;
  const holdLeft = a.status === "pending_payment" ? minutesLeft(a.hold_expires_at, now) : 0;
  // Rails has the final say (cancel_too_late); this only hides a button that cannot work.
  const canCancel =
    a.status === "pending_payment" || (a.status === "confirmed" && departsAt(a.schedule) > now);
  const fare = formatFare(a.fare);

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
          <StatusBadge status={a.status} paid={paid} />
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
          {fare && <span className="font-mono font-semibold tabular-nums text-on-surface">{fare}</span>}
          {a.refund && <RefundNote refund={a.refund} currency={a.fare?.currency ?? "INR"} />}
          {holdLeft > 0 && (
            <span className="font-mono text-amber-700" data-testid="hold-left">
              {holdLeft} min left to pay
            </span>
          )}
        </div>
        {cancel.isError && (
          <p className="mt-2 text-xs text-red-600">{bffErrorMessage(cancel.error)}</p>
        )}
        {refundStarted && a.refund?.status !== "failed" && (
          <p className="mt-2 text-xs text-on-surface-variant">Cancelled. Your fare will be refunded to the same payment method.</p>
        )}
      </div>

      {/* Actions */}
      <div className="flex shrink-0 items-center gap-2">
        {holdLeft > 0 && (
          <Link
            href={`/employee/reservations/${a.uid}/pay`}
            className="inline-flex items-center gap-1 rounded-lg bg-brand-600 px-3 py-1.5 font-mono text-[10px] font-bold uppercase tracking-wider text-white transition-all hover:bg-brand-700"
          >
            <CreditCard className="h-3 w-3" />
            Pay now
          </Link>
        )}
        {!canCancel ? null : confirming ? (
          <div className="flex items-center gap-2">
            <button
              onClick={() => {
                const refundDue = paid && a.status === "confirmed";
                cancel.mutate(a.uid, { onSuccess: () => setRefundStarted(refundDue) });
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
  const now = useNow();

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
            <ReservationCard key={reservation.id} reservation={reservation} now={now} />
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

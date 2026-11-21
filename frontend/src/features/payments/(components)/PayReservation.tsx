"use client";

import { useState } from "react";
import dynamic from "next/dynamic";
import Link from "next/link";
import { Clock, CreditCard, MapPin } from "lucide-react";
import { useReservation, bffErrorMessage } from "@/features/reservations/(queries)/queries";
import { readPaymentSession, usePaymentStatus, useRetryPayment } from "../(queries)/queries";
import { formatFare, minutesLeft, useNow } from "./format";

// The SDK touches window, so the checkout renders only in the browser.
const Checkout = dynamic(() => import("./Checkout"), { ssr: false });

const RETRYABLE = ["failed", "cancelled"];

function Panel({ children }: { children: React.ReactNode }) {
  return <div className="mx-auto max-w-xl rounded-2xl bg-surface-container-lowest p-6 shadow-sm">{children}</div>;
}

export function PayReservation({ uid }: { uid: string }) {
  const now = useNow();
  const reservation = useReservation(uid);
  const payment = usePaymentStatus(uid);
  const retry = useRetryPayment(uid);
  // Read once on mount; a retry replaces it with the new session.
  const [session, setSession] = useState<IPaymentSession | null>(() =>
    typeof window === "undefined" ? null : readPaymentSession(uid),
  );

  const resultPath = `/employee/reservations/${uid}/result`;

  if (reservation.isLoading || payment.isLoading) {
    return (
      <Panel>
        <p className="text-sm text-on-surface-variant">Loading your booking...</p>
      </Panel>
    );
  }

  if (reservation.isError || payment.isError || !reservation.data || !payment.data) {
    return (
      <Panel>
        <p className="text-sm text-red-600">{bffErrorMessage(reservation.error ?? payment.error)}</p>
        <Link href="/employee/reservations" className="mt-4 inline-block text-sm text-brand-600 underline">
          Back to reservations
        </Link>
      </Panel>
    );
  }

  const a = reservation.data.data.attributes;
  const p = payment.data.data;
  const left = minutesLeft(p.hold_expires_at, now);
  const fare = formatFare(a.fare);

  const header = (
    <div className="mb-6">
      <p className="mb-2 font-mono text-[10px] uppercase tracking-widest text-on-surface-variant">Pay for your ride</p>
      <h1 className="text-2xl font-black tracking-tight text-on-surface">{fare ?? "Ride"}</h1>
      <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-on-surface-variant">
        <span className="inline-flex items-center gap-1">
          <MapPin className="h-3 w-3" />
          {a.schedule.start_point} · {a.schedule.date} · {a.schedule.departure_time}
        </span>
        {p.status === "pending_payment" && left > 0 && (
          <span className="inline-flex items-center gap-1 text-amber-700" data-testid="hold-left">
            <Clock className="h-3 w-3" />
            Seat held for {left} min
          </span>
        )}
      </div>
    </div>
  );

  // Only a held, unexpired seat can be paid for; anything else is shown on the result page.
  if (p.status !== "pending_payment" || left === 0) {
    return (
      <Panel>
        {header}
        <p className="text-sm text-on-surface-variant">This booking is no longer waiting for payment.</p>
        <Link href={resultPath} className="mt-4 inline-block text-sm text-brand-600 underline">
          See booking status
        </Link>
      </Panel>
    );
  }

  const canRetry = RETRYABLE.includes(p.payment_status ?? "");

  if (!session || canRetry) {
    return (
      <Panel>
        {header}
        <p className="text-sm text-on-surface-variant">
          {canRetry
            ? "Your last payment did not go through. No money was taken. You can try again while your seat is held."
            : "This payment was started in another browser tab. Finish it there, or check its status. If it does not go through, you can try again here."}
        </p>
        {retry.isError && <p className="mt-3 text-sm text-red-600">{bffErrorMessage(retry.error)}</p>}
        <div className="mt-4 flex items-center gap-4">
          {canRetry && (
          <button
            onClick={() => retry.mutate(undefined, { onSuccess: (res) => setSession(res.data) })}
            disabled={retry.isPending}
            className="inline-flex items-center gap-2 rounded-lg bg-brand-600 px-4 py-2 font-mono text-xs font-bold uppercase tracking-wider text-white transition-all hover:bg-brand-700 disabled:opacity-50"
          >
            <CreditCard className="h-3.5 w-3.5" />
            {retry.isPending ? "Starting..." : "Try payment again"}
          </button>
          )}
          <Link href={resultPath} className="text-sm text-brand-600 underline">
            Check status
          </Link>
        </div>
      </Panel>
    );
  }

  return (
    <Panel>
      {header}
      <Checkout
        key={session.client_secret}
        clientSecret={session.client_secret}
        publishableKey={session.publishable_key}
        returnUrl={`${window.location.origin}${resultPath}`}
        label={fare ? `Pay ${fare}` : "Pay"}
      />
    </Panel>
  );
}

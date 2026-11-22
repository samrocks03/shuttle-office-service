"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { CheckCircle2, Clock, Loader2, XCircle } from "lucide-react";
import { cn } from "@/lib/utils";
import { bffErrorMessage } from "@/features/reservations/(queries)/queries";
import { clearPaymentSession, errorStatus, usePaymentStatus } from "../(queries)/queries";

// After this long without a final status, say that it is taking long.
const SLOW_AFTER_MS = 30_000;

const CONNECTOR_NAMES: Record<string, string> = {
  stripe: "Stripe",
  stripe_test: "Stripe Dummy",
  razorpay: "Razorpay",
};

/**
 * Shows where a reservation's payment stands. It polls Rails every 1.5 s while the reservation is
 * pending_payment and only reports what Rails says; it never marks anything paid itself.
 */
export function PaymentResult({ uid }: { uid: string }) {
  const { data, error, isError, isFetching, refetch, dataUpdatedAt } = usePaymentStatus(uid, { poll: true });
  const [openedAt] = useState(() => Date.now());

  const p = data?.data;
  const final = p && p.status !== "pending_payment";

  useEffect(() => {
    if (final) clearPaymentSession(uid);
  }, [final, uid]);

  let tone = "border-[#c7c4d8]/30";
  let icon = <Loader2 className="h-6 w-6 animate-spin text-brand-600" />;
  let title = "Confirming your payment...";
  let body = "We are waiting for the payment provider to confirm. This page updates by itself.";
  let state = "waiting";

  // Polling has stopped on an error, so never keep saying "Confirming..." over stale data.
  if (isError && errorStatus(error) === 401) {
    tone = "border-red-500/40";
    icon = <XCircle className="h-6 w-6 text-red-600" />;
    title = "Please sign in again";
    body = "Your session has ended, so we could not check the payment. Sign in to see its status.";
    state = "signed_out";
  } else if (isError && !p) {
    tone = "border-red-500/40";
    icon = <XCircle className="h-6 w-6 text-red-600" />;
    title = "We could not load this booking";
    body = bffErrorMessage(error);
    state = "error";
  } else if (isError && p?.status === "pending_payment") {
    tone = "border-red-500/40";
    icon = <XCircle className="h-6 w-6 text-red-600" />;
    title = "We could not refresh the payment status";
    body = "The last status we saw was still waiting for the payment provider. Check again in a moment.";
    state = "poll_error";
  } else if (p?.status === "confirmed") {
    tone = "border-emerald-600/50";
    icon = <CheckCircle2 className="h-6 w-6 text-emerald-600" />;
    title = "Paid. Your seat is confirmed.";
    body = p.connector
      ? `Payment received through ${CONNECTOR_NAMES[p.connector] ?? p.connector}. Your boarding pass is on its way to your email.`
      : "Your boarding pass is on its way to your email.";
    state = "paid";
  } else if (p?.status === "expired") {
    tone = "border-amber-500/50";
    icon = <Clock className="h-6 w-6 text-amber-600" />;
    title = "Your seat hold has expired";
    body = "The payment was not completed in time, so the seat was released. You can book the ride again if seats are left.";
    state = "expired";
  } else if (p?.status === "cancelled") {
    tone = "border-[#c7c4d8]/50";
    icon = <XCircle className="h-6 w-6 text-on-surface-variant" />;
    title = "This booking was cancelled";
    body = "If a payment was taken, it is refunded to the same payment method.";
    state = "cancelled";
  } else if (p && ["failed", "cancelled"].includes(p.payment_status ?? "")) {
    tone = "border-red-500/40";
    icon = <XCircle className="h-6 w-6 text-red-600" />;
    title = "The payment did not go through";
    body = "No money was taken. Your seat is still held for a few minutes, so you can try again.";
    state = "failed";
  } else if (dataUpdatedAt - openedAt > SLOW_AFTER_MS) {
    body = "This is taking longer than usual. We are still waiting for the payment provider. You can leave this page; your reservations list will show the result.";
    state = "slow";
  }

  return (
    <div className={cn("mx-auto max-w-xl rounded-2xl border-2 bg-surface-container-lowest p-6 shadow-sm", tone)}>
      <div className="flex items-start gap-3">
        {icon}
        <div>
          <h1 className="text-xl font-bold text-on-surface" data-testid="result-title" data-state={state}>
            {title}
          </h1>
          <p className="mt-2 text-sm text-on-surface-variant">{body}</p>
        </div>
      </div>
      <div className="mt-6 flex flex-wrap gap-4 text-sm">
        {(state === "poll_error" || state === "error") && (
          <button
            type="button"
            onClick={() => refetch()}
            disabled={isFetching}
            className="font-medium text-brand-600 underline disabled:opacity-50"
          >
            {isFetching ? "Checking..." : "Check again"}
          </button>
        )}
        {state === "signed_out" && (
          <Link
            href={`/login?redirect=${encodeURIComponent(`/employee/reservations/${uid}/result`)}`}
            className="font-medium text-brand-600 underline"
          >
            Sign in
          </Link>
        )}
        {state === "failed" && (
          <Link href={`/employee/reservations/${uid}/pay`} className="font-medium text-brand-600 underline">
            Try payment again
          </Link>
        )}
        <Link href="/employee/reservations" className="text-brand-600 underline">
          My reservations
        </Link>
        <Link href="/employee/schedules" className="text-brand-600 underline">
          Book another ride
        </Link>
      </div>
    </div>
  );
}

"use client";

import { useMemo, useState } from "react";
import { HyperElements, PaymentElement, useHyper, useWidgets } from "@juspay-tech/react-hyper-js";

const SDK_URL = process.env.NEXT_PUBLIC_HYPERSWITCH_SDK_URL || "http://localhost:9050";
const BACKEND_URL = process.env.NEXT_PUBLIC_HYPERSWITCH_URL || "http://localhost:8080";

// The npm loader (@juspay-tech/hyper-js) always fetches HyperLoader.js from Juspay's hosted
// sandbox. Hyperswitch here is self-hosted, so the same script is loaded from the local SDK server.
function loadLocalHyper(publishableKey: string): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const make = () => resolve(window.Hyper!(publishableKey, { customBackendUrl: BACKEND_URL }));
    if (window.Hyper) return make();
    const script = document.createElement("script");
    script.src = `${SDK_URL}/HyperLoader.js`;
    script.onload = make;
    script.onerror = () => reject(new Error("checkout_sdk_unavailable"));
    document.body.appendChild(script);
  });
}

function PayForm({ returnUrl, label }: { returnUrl: string; label: string }) {
  const hyper = useHyper();
  const elements = useWidgets();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function pay(e: React.FormEvent) {
    e.preventDefault();
    if (!hyper) return;
    setBusy(true);
    setError(null);
    const res = await hyper.confirmPayment({
      elements,
      confirmParams: { return_url: returnUrl },
      redirect: "if_required",
    });
    // A field problem stays on this page. Anything else goes to the result page, which asks the
    // server what happened; the browser's view of the outcome is never trusted.
    if (res?.error?.type === "validation_error") {
      setError("Please check the payment details and try again.");
      setBusy(false);
      return;
    }
    window.location.href = returnUrl;
  }

  return (
    <form onSubmit={pay} className="space-y-4">
      {/* Card and UPI details are entered only inside the Hyperswitch iframe. */}
      <PaymentElement id="payment-element" options={{ layout: "tabs" }} />
      {error && <p className="text-sm text-red-600">{error}</p>}
      <button
        type="submit"
        disabled={busy || !hyper}
        className="w-full rounded-lg bg-brand-600 px-4 py-2.5 font-mono text-xs font-bold uppercase tracking-wider text-white transition-all hover:bg-brand-700 active:translate-y-px disabled:opacity-50"
      >
        {busy ? "Paying..." : label}
      </button>
    </form>
  );
}

export default function Checkout({
  clientSecret,
  publishableKey,
  returnUrl,
  label,
}: {
  clientSecret: string;
  publishableKey: string;
  returnUrl: string;
  label: string;
}) {
  const hyper = useMemo(() => loadLocalHyper(publishableKey), [publishableKey]);

  return (
    <HyperElements hyper={hyper} options={{ clientSecret, appearance: { theme: "default" } }}>
      <PayForm returnUrl={returnUrl} label={label} />
    </HyperElements>
  );
}

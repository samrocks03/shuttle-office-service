import { useEffect, useState } from "react";

export function formatFare(fare: { amount_minor: number; currency: string } | null | undefined) {
  if (!fare) return null;
  const amount = (fare.amount_minor / 100).toFixed(fare.amount_minor % 100 === 0 ? 0 : 2);
  return fare.currency === "INR" ? `Rs ${amount}` : `${fare.currency} ${amount}`;
}

/** Current time, refreshed every `intervalMs`, for hold countdowns. */
export function useNow(intervalMs = 15_000) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), intervalMs);
    return () => clearInterval(t);
  }, [intervalMs]);
  return now;
}

/** Whole minutes left on a seat hold (rounded up), or 0 once it has passed. */
export function minutesLeft(holdExpiresAt: string | null | undefined, now: number) {
  if (!holdExpiresAt) return 0;
  const ms = new Date(holdExpiresAt).getTime() - now;
  return ms > 0 ? Math.ceil(ms / 60_000) : 0;
}

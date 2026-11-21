/**
 * Formats an amount held in minor units (paise, cents) for display.
 *
 * INR is rendered as "Rs 35" (whole rupees) or "Rs 35.50" (with paise) using integer math only.
 * Other currencies go through Intl.NumberFormat.
 */
export function formatMoney(amountMinor: number, currency: string): string {
  if (currency === "INR") {
    const sign = amountMinor < 0 ? "-" : "";
    const abs = Math.abs(amountMinor);
    const rupees = Math.trunc(abs / 100);
    const paise = abs % 100;
    return paise === 0
      ? `${sign}Rs ${rupees}`
      : `${sign}Rs ${rupees}.${String(paise).padStart(2, "0")}`;
  }

  return new Intl.NumberFormat("en-US", { style: "currency", currency }).format(amountMinor / 100);
}

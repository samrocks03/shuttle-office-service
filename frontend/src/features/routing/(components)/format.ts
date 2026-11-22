/** Kilometres for a table cell: "18.4", or an em dash when there is no value. */
export function formatKm(km: number | null | undefined): string {
  return km == null ? "—" : String(Number(km.toFixed(3)));
}

export const SERVICE_CLASS_LABELS: Record<string, string> = { ac: "AC", non_ac: "Non-AC" };

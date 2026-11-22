import { formatMoney } from "@/shared/lib/money";
import { cn } from "@/lib/utils";

const SERVICE_CLASS_LABELS = { ac: "AC", non_ac: "Non-AC" } as const;

interface FareBadgeProps {
  fare: IScheduleFare | null;
  serviceClass?: "non_ac" | "ac" | null;
  className?: string;
}

/** "Rs 35 · AC · 18.4 km", or "Fare not set" when the schedule has no fare. */
export function FareBadge({ fare, serviceClass, className }: FareBadgeProps) {
  if (!fare) {
    return (
      <span
        className={cn(
          "inline-flex items-center rounded-full border border-[#c7c4d8]/30 px-2.5 py-0.5 font-mono text-[11px] font-semibold text-on-surface-variant",
          className,
        )}
      >
        Fare not set
      </span>
    );
  }

  const parts = [formatMoney(fare.amount_minor, fare.currency)];
  if (serviceClass) parts.push(SERVICE_CLASS_LABELS[serviceClass]);
  parts.push(`${fare.distance_km.toFixed(1)} km`);

  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full border border-brand-600/20 bg-brand-600/10 px-2.5 py-0.5 font-mono text-[11px] font-semibold tabular-nums text-brand-700",
        className,
      )}
    >
      {parts.join(" · ")}
    </span>
  );
}

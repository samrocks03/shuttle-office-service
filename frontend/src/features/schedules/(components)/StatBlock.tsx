import { type ReactNode } from "react";

export default function StatBlock({
  icon,
  label,
  value,
}: {
  icon: ReactNode;
  label: string;
  value: number;
}) {
  return (
    <div className="flex items-center gap-3">
      <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-surface-container-low text-on-surface-variant">
        {icon}
      </div>
      <div>
        <div className="font-mono text-lg font-bold tabular-nums text-on-surface">
          {value}
        </div>
        <div className="font-mono text-[9px] uppercase tracking-wide text-on-surface-variant">
          {label}
        </div>
      </div>
    </div>
  );
}

"use client";

import { useState, useMemo } from "react";
import Link from "next/link";
import { Search, ChevronLeft, ChevronRight, Bus, Clock, MapPin, Users, Check } from "lucide-react";
import { cn } from "@/lib/utils";
import { useSchedules } from "../(queries)/queries";
import { useCreateReservation } from "@/features/reservations/(queries)/queries";
import StatBlock from "./StatBlock";

const PER_PAGE = 10;

function formatTime(time: string) {
  return time; // already "HH:MM" from backend
}

function SeatsIndicator({ available, capacity }: { available: number; capacity?: number }) {
  const ratio = capacity ? available / capacity : 1;
  const color =
    ratio > 0.3
      ? "bg-accent-500/10 text-accent-700"
      : ratio > 0
        ? "bg-amber-500/10 text-amber-700"
        : "bg-red-500/10 text-red-700";

  return (
    <span className={cn("inline-flex items-center gap-1 rounded-full px-2.5 py-1 font-mono text-[11px] font-semibold", color)}>
      <Users className="h-3 w-3" />
      {available}{capacity ? `/${capacity}` : ""}
    </span>
  );
}

function ReserveButton({ scheduleId }: { scheduleId: number }) {
  const create = useCreateReservation();
  const [confirmed, setConfirmed] = useState(false);

  if (confirmed) {
    return (
      <span className="inline-flex items-center gap-1 rounded-lg bg-accent-500/10 px-3 py-1.5 font-mono text-[10px] font-bold uppercase tracking-wider text-accent-700">
        <Check className="h-3 w-3" />
        Booked
      </span>
    );
  }

  return (
    <button
      onClick={() =>
        create.mutate(scheduleId, {
          onSuccess: () => setConfirmed(true),
        })
      }
      disabled={create.isPending}
      className="rounded-lg bg-brand-600 px-3 py-1.5 font-mono text-[10px] font-bold uppercase tracking-wider text-white transition-all hover:bg-brand-700 active:translate-y-px disabled:opacity-50"
    >
      {create.isPending ? "Booking..." : "Reserve"}
    </button>
  );
}

function ScheduleRow({ schedule, isAuthenticated }: { schedule: IScheduleResource; isAuthenticated: boolean }) {
  const a = schedule.attributes;

  return (
    <div className="group flex items-center gap-4 rounded-xl border border-transparent bg-surface-container-lowest px-5 py-4 transition-all hover:border-[#c7c4d8]/20 hover:shadow-sm">
      {/* Bus badge */}
      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-brand-600/10">
        <Bus className="h-4 w-4 text-brand-600" />
      </div>

      {/* Route info */}
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          {a.bus_number && (
            <span className="rounded bg-surface-container-low px-1.5 py-0.5 font-mono text-[10px] font-bold uppercase tracking-wider text-on-surface-variant">
              {a.bus_number}
            </span>
          )}
          {a.company_name && (
            <span className="truncate text-xs text-on-surface-variant">
              {a.company_name}
            </span>
          )}
        </div>
        <div className="mt-1 flex items-center gap-1.5 text-sm text-on-surface">
          <MapPin className="h-3 w-3 text-on-surface-variant" />
          <span className="truncate font-medium">{a.start_point}</span>
        </div>
      </div>

      {/* Times */}
      <div className="hidden items-center gap-2 sm:flex">
        <div className="text-right">
          <div className="font-mono text-sm font-bold tabular-nums text-on-surface">
            {formatTime(a.departure_time)}
          </div>
          <div className="font-mono text-[9px] uppercase tracking-wide text-on-surface-variant">
            Depart
          </div>
        </div>
        <span className="font-mono text-xs text-on-surface-variant/40">→</span>
        <div>
          <div className="font-mono text-sm font-bold tabular-nums text-on-surface">
            {formatTime(a.arrival_time)}
          </div>
          <div className="font-mono text-[9px] uppercase tracking-wide text-on-surface-variant">
            Arrive
          </div>
        </div>
      </div>

      {/* Seats */}
      <SeatsIndicator available={a.available_seats} capacity={a.bus_capacity} />

      {/* Reserve action */}
      {isAuthenticated && a.available_seats > 0 && (
        <ReserveButton scheduleId={Number(schedule.id)} />
      )}
    </div>
  );
}

function EmptyState() {
  return (
    <div className="flex flex-col items-center justify-center py-20 text-center">
      <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-surface-container-low">
        <Bus className="h-7 w-7 text-on-surface-variant/40" />
      </div>
      <h3 className="mt-4 font-semibold text-on-surface">No schedules found</h3>
      <p className="mt-1 max-w-xs text-sm text-on-surface-variant">
        Try adjusting your filters or check back later for new routes.
      </p>
    </div>
  );
}

function SkeletonRow() {
  return (
    <div className="flex items-center gap-4 rounded-xl bg-surface-container-lowest px-5 py-4">
      <div className="h-10 w-10 shrink-0 animate-pulse rounded-lg bg-surface-container-low" />
      <div className="flex-1 space-y-2">
        <div className="h-3 w-24 animate-pulse rounded bg-surface-container-low" />
        <div className="h-3 w-40 animate-pulse rounded bg-surface-container-low" />
      </div>
      <div className="hidden space-y-1 sm:block">
        <div className="h-4 w-20 animate-pulse rounded bg-surface-container-low" />
        <div className="h-2 w-12 animate-pulse rounded bg-surface-container-low" />
      </div>
      <div className="h-6 w-14 animate-pulse rounded-full bg-surface-container-low" />
    </div>
  );
}

export function ScheduleBrowser({ dashboardPath }: { dashboardPath?: string }) {
  const [filters, setFilters] = useState<IScheduleFilters>({
    page: 1,
    per_page: PER_PAGE,
  });
  const [dateInput, setDateInput] = useState("");
  const [routeInput, setRouteInput] = useState("");

  const { data, isFetching, isLoading } = useSchedules(filters);

  const schedules = data?.data ?? [];
  const meta = data?.meta;

  const stats = useMemo(() => {
    const totalSeats = schedules.reduce((sum, s) => sum + (s.attributes.bus_capacity ?? 0), 0);
    const availableSeats = schedules.reduce((sum, s) => sum + s.attributes.available_seats, 0);
    const companies = new Set(schedules.map((s) => s.attributes.company_name).filter(Boolean));
    return { totalSeats, availableSeats, companies: companies.size, routes: schedules.length };
  }, [schedules]);

  function handleSearch(e: { preventDefault(): void }) {
    e.preventDefault();
    setFilters((prev) => ({
      ...prev,
      page: 1,
      date: dateInput || undefined,
      start_point: routeInput || undefined,
    }));
  }

  function goToPage(page: number) {
    setFilters((prev) => ({ ...prev, page }));
  }

  return (
    <div className="mx-auto max-w-7xl px-6 py-10">
      {/* Page header */}
      <div className="mb-8">
        <p className="mb-2 font-mono text-[10px] uppercase tracking-widest text-on-surface-variant">
          Public schedules
        </p>
        <h1 className="text-3xl font-black tracking-tight text-on-surface">
          Browse Routes
        </h1>
        <p className="mt-2 max-w-lg text-on-surface-variant">
          Find available shuttle routes, compare departure times, and check seat availability.
        </p>
      </div>

      {/* 60/40 layout */}
      <div className="grid gap-8 lg:grid-cols-[1fr_340px]">
        {/* Left: filters + list */}
        <div>
          {/* Filter bar */}
          <form onSubmit={handleSearch} className="mb-6 flex flex-wrap items-end gap-3">
            <div className="flex-1 min-w-[140px]">
              <label className="mb-1.5 block font-mono text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">
                Date
              </label>
              <input
                type="date"
                value={dateInput}
                onChange={(e) => setDateInput(e.target.value)}
                className="w-full rounded-lg border border-[#c7c4d8]/30 bg-surface-container-low px-3 py-2 font-mono text-sm text-on-surface outline-none transition-colors focus:border-brand-600 focus:ring-1 focus:ring-brand-600"
              />
            </div>
            <div className="flex-1 min-w-[180px]">
              <label className="mb-1.5 block font-mono text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">
                Start point
              </label>
              <input
                type="text"
                value={routeInput}
                onChange={(e) => setRouteInput(e.target.value)}
                placeholder="e.g. Central Hub"
                className="w-full rounded-lg border border-[#c7c4d8]/30 bg-surface-container-low px-3 py-2 text-sm text-on-surface placeholder:text-on-surface-variant/50 outline-none transition-colors focus:border-brand-600 focus:ring-1 focus:ring-brand-600"
              />
            </div>
            <button
              type="submit"
              className="inline-flex items-center gap-2 rounded-lg bg-brand-600 px-4 py-2 font-mono text-xs font-bold uppercase tracking-wider text-white transition-all hover:bg-brand-700 active:translate-y-px"
            >
              <Search className="h-3.5 w-3.5" />
              Search
            </button>
          </form>

          {/* Schedule list */}
          <div className="space-y-2">
            {isLoading ? (
              Array.from({ length: 5 }).map((_, i) => <SkeletonRow key={i} />)
            ) : schedules.length === 0 ? (
              <EmptyState />
            ) : (
              schedules.map((schedule) => (
                <ScheduleRow key={schedule.id} schedule={schedule} isAuthenticated={!!dashboardPath} />
              ))
            )}
          </div>

          {/* Pagination */}
          {meta && meta.total_pages > 1 && (
            <div className="mt-6 flex items-center justify-between border-t border-[#c7c4d8]/15 pt-4">
              <button
                onClick={() => goToPage(meta.current_page - 1)}
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
                onClick={() => goToPage(meta.current_page + 1)}
                disabled={meta.current_page >= meta.total_pages}
                className="inline-flex items-center gap-1 rounded-lg px-3 py-1.5 font-mono text-xs font-semibold text-on-surface-variant transition-colors hover:bg-surface-container-low disabled:opacity-30 disabled:pointer-events-none"
              >
                Next
                <ChevronRight className="h-3.5 w-3.5" />
              </button>
            </div>
          )}
        </div>

        {/* Right: stats panel */}
        <aside className="hidden lg:block">
          <div className={cn(
            "sticky top-24 space-y-6 rounded-2xl bg-surface-dim/40 p-6",
            isFetching && "opacity-60 transition-opacity"
          )}>
            <div>
              <p className="mb-4 font-mono text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">
                Current view
              </p>
              <div className="space-y-4">
                <StatBlock
                  icon={<Bus className="h-4 w-4" />}
                  label="Routes shown"
                  value={stats.routes}
                />
                <StatBlock
                  icon={<Users className="h-4 w-4" />}
                  label="Available seats"
                  value={stats.availableSeats}
                />
                <StatBlock
                  icon={<Clock className="h-4 w-4" />}
                  label="Total capacity"
                  value={stats.totalSeats}
                />
                <StatBlock
                  icon={<MapPin className="h-4 w-4" />}
                  label="Companies"
                  value={stats.companies}
                />
              </div>
            </div>

            <div className="border-t border-[#c7c4d8]/15 pt-5">
              {dashboardPath ? (
                <>
                  <p className="text-sm font-medium text-on-surface">
                    Ready to reserve?
                  </p>
                  <p className="mt-1 text-xs leading-relaxed text-on-surface-variant">
                    Head to your dashboard to book seats on available routes.
                  </p>
                  <Link
                    href={dashboardPath}
                    className="mt-3 block rounded-lg bg-gradient-to-r from-brand-600 to-brand-500 py-2 text-center font-mono text-xs font-bold uppercase tracking-wider text-white transition-all hover:opacity-90 active:translate-y-px"
                  >
                    Go to dashboard
                  </Link>
                </>
              ) : (
                <>
                  <p className="text-sm font-medium text-on-surface">
                    Want to reserve a seat?
                  </p>
                  <p className="mt-1 text-xs leading-relaxed text-on-surface-variant">
                    Sign in to your account to book seats on any available route.
                  </p>
                  <Link
                    href="/login"
                    className="mt-3 block rounded-lg bg-gradient-to-r from-brand-600 to-brand-500 py-2 text-center font-mono text-xs font-bold uppercase tracking-wider text-white transition-all hover:opacity-90 active:translate-y-px"
                  >
                    Sign in to reserve
                  </Link>
                </>
              )}
            </div>
          </div>
        </aside>
      </div>
    </div>
  );
}

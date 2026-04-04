"use client";

import { useState, useMemo } from "react";
import {
  Search,
  Bus,
  Clock,
  MapPin,
  Users,
  Check,
  ChevronLeft,
  ChevronRight,
  Route,
  CalendarDays,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useSchedules } from "../(queries)/queries";
import { useCreateReservation } from "@/features/reservations/(queries)/queries";

const PER_PAGE = 8;

/* ── Helpers ── */

function formatTime(time: string) {
  return time;
}

function todayISO() {
  return new Date().toISOString().split("T")[0];
}

/* ── Sub-components ── */

function Seatsbadge({ available, capacity }: { available: number; capacity?: number }) {
  const ratio = capacity ? available / capacity : 1;
  const style =
    available === 0
      ? "bg-red-500/10 text-red-600 border-red-500/20"
      : ratio <= 0.25
        ? "bg-amber-500/10 text-amber-700 border-amber-500/20"
        : "bg-accent-500/10 text-accent-700 border-accent-500/20";

  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full border px-2.5 py-0.5 font-mono text-[11px] font-black tabular-nums uppercase",
        style,
      )}
    >
      {available === 0 ? "Full" : `${String(available).padStart(2, "0")} seats`}
    </span>
  );
}

function ReserveButton({ scheduleId }: { scheduleId: number }) {
  const create = useCreateReservation();
  const [confirmed, setConfirmed] = useState(false);

  if (confirmed) {
    return (
      <span className="inline-flex items-center gap-1 rounded-lg bg-accent-500/10 px-4 py-2 font-mono text-[11px] font-bold uppercase tracking-wider text-accent-700">
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
      className="rounded-lg bg-brand-600 px-4 py-2 font-mono text-[11px] font-bold uppercase tracking-wider text-white transition-all hover:bg-brand-700 active:translate-y-px disabled:opacity-50"
    >
      {create.isPending ? "Booking..." : "Reserve"}
    </button>
  );
}

function ScheduleRow({ schedule }: { schedule: IScheduleResource }) {
  const a = schedule.attributes;

  return (
    <div
      className={cn(
        "flex flex-col gap-4 rounded-xl border bg-surface-container-lowest p-4 transition-all sm:flex-row sm:items-center sm:justify-between",
        a.available_seats === 0
          ? "border-[#c7c4d8]/5 opacity-70"
          : "border-[#c7c4d8]/10 hover:border-brand-600/20 hover:shadow-sm",
      )}
    >
      {/* Route info */}
      <div className="flex-grow">
        <div className="flex items-center gap-3">
          <Route className={cn("h-4 w-4", a.available_seats === 0 ? "text-on-surface/30" : "text-brand-600")} />
          <h3 className="text-sm font-bold text-on-surface">{a.start_point}</h3>
        </div>
        <div className="mt-2 flex items-center gap-6">
          <div className="flex flex-col">
            <span className="font-mono text-[9px] font-bold uppercase text-on-surface/40">Date</span>
            <span className="font-mono text-sm tabular-nums">{a.date}</span>
          </div>
          <div className="flex flex-col">
            <span className="font-mono text-[9px] font-bold uppercase text-on-surface/40">Departure</span>
            <span className={cn("font-mono text-sm font-bold tabular-nums", a.available_seats > 0 ? "text-brand-600" : "text-on-surface")}>
              {formatTime(a.departure_time)}
            </span>
          </div>
          <div className="flex flex-col">
            <span className="font-mono text-[9px] font-bold uppercase text-on-surface/40">Arrival</span>
            <span className="font-mono text-sm tabular-nums">{formatTime(a.arrival_time)}</span>
          </div>
          {a.company_name && (
            <div className="hidden flex-col lg:flex">
              <span className="font-mono text-[9px] font-bold uppercase text-on-surface/40">Operator</span>
              <span className="text-sm text-on-surface-variant">{a.company_name}</span>
            </div>
          )}
        </div>
      </div>

      {/* Right: seats + action */}
      <div className="flex items-center justify-between gap-4 sm:justify-end">
        <Seatsbadge available={a.available_seats} capacity={a.bus_capacity} />
        {a.available_seats > 0 ? (
          <ReserveButton scheduleId={Number(schedule.id)} />
        ) : (
          <button
            disabled
            className="cursor-not-allowed rounded-lg bg-surface-dim px-4 py-2 font-mono text-[11px] font-bold uppercase tracking-wider text-on-surface/30"
          >
            Waitlist
          </button>
        )}
      </div>
    </div>
  );
}

function SkeletonRow() {
  return (
    <div className="flex items-center gap-4 rounded-xl bg-surface-container-lowest p-4">
      <div className="h-4 w-4 animate-pulse rounded bg-surface-container-low" />
      <div className="flex-1 space-y-2">
        <div className="h-4 w-48 animate-pulse rounded bg-surface-container-low" />
        <div className="flex gap-6">
          <div className="h-3 w-20 animate-pulse rounded bg-surface-container-low" />
          <div className="h-3 w-16 animate-pulse rounded bg-surface-container-low" />
          <div className="h-3 w-16 animate-pulse rounded bg-surface-container-low" />
        </div>
      </div>
      <div className="h-6 w-20 animate-pulse rounded-full bg-surface-container-low" />
      <div className="h-8 w-20 animate-pulse rounded-lg bg-surface-container-low" />
    </div>
  );
}

function EmptyState() {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center">
      <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-surface-container-low">
        <Bus className="h-6 w-6 text-on-surface-variant/40" />
      </div>
      <h3 className="mt-4 font-semibold text-on-surface">No schedules found</h3>
      <p className="mt-1 max-w-xs text-sm text-on-surface-variant">
        Try a different date or route, or check back later for new departures.
      </p>
    </div>
  );
}

/* ── Route Timeline (right panel) ── */

function RouteTimeline({ schedule }: { schedule: IScheduleResource | undefined }) {
  if (!schedule) {
    return (
      <div className="rounded-2xl border border-[#c7c4d8]/10 bg-surface-container-lowest p-6">
        <p className="text-sm text-on-surface-variant">Select a date to see upcoming routes.</p>
      </div>
    );
  }

  const a = schedule.attributes;

  return (
    <div className="rounded-2xl border border-[#c7c4d8]/10 bg-surface-container-lowest p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-full bg-brand-600/10 text-brand-600">
            <Bus className="h-5 w-5" />
          </div>
          <div>
            <div className="font-mono text-[10px] font-bold uppercase text-on-surface-variant">
              {a.bus_number ?? "Shuttle"}
            </div>
            <div className="text-sm font-bold text-on-surface">{a.start_point}</div>
          </div>
        </div>
        <div className="text-right">
          <div className="font-mono text-lg font-black tabular-nums text-accent-600 leading-none">
            {formatTime(a.departure_time)}
          </div>
          <div className="font-mono text-[9px] font-bold uppercase text-on-surface/40">Departure</div>
        </div>
      </div>

      {/* Timeline */}
      <div className="relative space-y-7 pl-6">
        <div className="absolute bottom-2 left-1.5 top-2 w-0.5 bg-[#c7c4d8]/30" />

        <div className="relative">
          <div className="absolute -left-[22px] top-1 h-3 w-3 rounded-full border-4 border-surface-container-lowest bg-accent-500 outline outline-1 outline-accent-500/20" />
          <div className="font-mono text-[10px] font-black uppercase text-accent-600">Departure</div>
          <div className="text-sm font-bold text-on-surface">{a.start_point}</div>
          <div className="font-mono text-xs tabular-nums text-on-surface-variant">{formatTime(a.departure_time)}</div>
        </div>

        <div className="relative">
          <div className="absolute -left-[22px] top-1 h-3 w-3 rounded-full border-4 border-surface-container-lowest bg-brand-600 outline outline-1 outline-brand-600/20" />
          <div className="font-mono text-[10px] font-black uppercase text-on-surface/40">In Transit</div>
          <div className="text-sm font-bold text-on-surface">En Route</div>
          {a.company_name && (
            <div className="text-xs text-on-surface-variant">Operated by {a.company_name}</div>
          )}
        </div>

        <div className="relative">
          <div className="absolute -left-[22px] top-1 h-3 w-3 rounded-full border-4 border-surface-container-lowest bg-surface-dim outline outline-1 outline-[#c7c4d8]" />
          <div className="font-mono text-[10px] font-black uppercase text-on-surface/40">Arrival</div>
          <div className="text-sm font-bold text-on-surface">Destination</div>
          <div className="font-mono text-xs tabular-nums text-on-surface-variant">{formatTime(a.arrival_time)}</div>
        </div>
      </div>

      {/* Seats remaining */}
      <div className="flex items-center justify-between rounded-xl bg-surface-container-low p-3">
        <span className="font-mono text-[10px] font-bold uppercase text-on-surface-variant">Seats remaining</span>
        <span className="font-mono text-sm font-black tabular-nums text-on-surface">
          {a.available_seats}{a.bus_capacity ? ` / ${a.bus_capacity}` : ""}
        </span>
      </div>
    </div>
  );
}

/* ── Map Placeholder ── */

function SystemMap() {
  return (
    <div className="relative aspect-[4/3] overflow-hidden rounded-2xl border border-[#c7c4d8]/10 bg-deep-void/5">
      {/* Decorative grid */}
      <div className="absolute inset-0 opacity-[0.03]" style={{
        backgroundImage: "linear-gradient(to right, currentColor 1px, transparent 1px), linear-gradient(to bottom, currentColor 1px, transparent 1px)",
        backgroundSize: "40px 40px",
      }} />

      {/* Decorative route lines */}
      <svg className="absolute inset-0 h-full w-full" viewBox="0 0 400 300" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M50 250 Q100 200 150 180 Q200 160 250 120 Q300 80 350 60" stroke="var(--color-brand-600)" strokeWidth="2" strokeDasharray="6 4" opacity="0.2" />
        <path d="M30 200 Q80 160 160 140 Q240 120 320 50" stroke="var(--color-accent-500)" strokeWidth="2" strokeDasharray="6 4" opacity="0.15" />
        <circle cx="150" cy="180" r="4" fill="var(--color-brand-600)" opacity="0.4" />
        <circle cx="250" cy="120" r="4" fill="var(--color-brand-600)" opacity="0.4" />
        <circle cx="350" cy="60" r="6" fill="var(--color-accent-500)" opacity="0.5" />
        <circle cx="350" cy="60" r="10" fill="var(--color-accent-500)" opacity="0.15" />
      </svg>

      {/* Overlay badge */}
      <div className="absolute left-4 top-4 flex items-center gap-2 rounded-lg border border-[#c7c4d8]/20 bg-surface-container-lowest/90 px-3 py-1.5 shadow-sm backdrop-blur">
        <span className="relative flex h-2 w-2">
          <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-accent-500 opacity-75" />
          <span className="relative inline-flex h-2 w-2 rounded-full bg-accent-500" />
        </span>
        <span className="font-mono text-[10px] font-bold uppercase">Live routes</span>
      </div>

      {/* Coming soon */}
      <div className="absolute inset-0 flex items-center justify-center">
        <div className="rounded-xl bg-surface-container-lowest/80 px-4 py-2 shadow-sm backdrop-blur">
          <span className="font-mono text-[10px] font-bold uppercase tracking-wider text-on-surface-variant">
            Interactive map coming soon
          </span>
        </div>
      </div>
    </div>
  );
}

/* ── Capacity Bento Stats ── */

function CapacityBento({ schedules }: { schedules: IScheduleResource[] }) {
  const stats = useMemo(() => {
    const totalCapacity = schedules.reduce((sum, s) => sum + (s.attributes.bus_capacity ?? 0), 0);
    const available = schedules.reduce((sum, s) => sum + s.attributes.available_seats, 0);
    const departures = schedules.length;
    const nextDeparture = schedules.find((s) => s.attributes.available_seats > 0);
    return { totalCapacity, available, departures, nextDeparture };
  }, [schedules]);

  return (
    <div className="grid grid-cols-2 gap-3">
      <div className="rounded-xl border border-[#c7c4d8]/10 bg-surface-container-lowest p-4">
        <div className="font-mono text-[9px] font-black uppercase text-on-surface/40">Departures</div>
        <div className="mt-1 font-mono text-xl font-black tabular-nums text-brand-600">
          {String(stats.departures).padStart(2, "0")}
        </div>
      </div>
      <div className="rounded-xl border border-[#c7c4d8]/10 bg-surface-container-lowest p-4">
        <div className="font-mono text-[9px] font-black uppercase text-on-surface/40">Seats Open</div>
        <div className="mt-1 font-mono text-xl font-black tabular-nums text-accent-600">
          {stats.available}
        </div>
      </div>
      <div className="col-span-2 rounded-xl border border-[#c7c4d8]/10 bg-surface-container-lowest p-4">
        <div className="font-mono text-[9px] font-black uppercase text-on-surface/40">Next Available</div>
        <div className="mt-1 font-mono text-sm font-bold tabular-nums text-on-surface">
          {stats.nextDeparture
            ? `${formatTime(stats.nextDeparture.attributes.departure_time)} — ${stats.nextDeparture.attributes.start_point}`
            : "No open seats"}
        </div>
      </div>
    </div>
  );
}

/* ── Main Component ── */

export function EmployeeScheduleBrowser() {
  const [dateInput, setDateInput] = useState(todayISO());
  const [routeInput, setRouteInput] = useState("");
  const [filters, setFilters] = useState<IScheduleFilters>({
    page: 1,
    per_page: PER_PAGE,
    date: todayISO(),
  });

  const { data, isLoading, isFetching } = useSchedules(filters);
  const schedules = data?.data ?? [];
  const meta = data?.meta;

  const nextDeparture = useMemo(
    () => schedules.find((s) => s.attributes.available_seats > 0),
    [schedules],
  );

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
    <div className="space-y-6">
      {/* Page header */}
      <div>
        <p className="mb-2 font-mono text-[10px] uppercase tracking-widest text-on-surface-variant">
          Transit board
        </p>
        <h1 className="text-2xl font-bold tracking-tight text-on-surface">Schedules</h1>
        <p className="mt-1 text-sm text-on-surface-variant">
          Find routes, check live availability, and reserve your seat.
        </p>
      </div>

      {/* 60/40 asymmetric layout */}
      <div className="flex flex-col gap-6 lg:flex-row">
        {/* Left panel — 60% */}
        <div className="w-full space-y-5 lg:w-[60%]">
          {/* Search & Filter Bar */}
          <form
            onSubmit={handleSearch}
            className="grid grid-cols-1 gap-3 rounded-2xl border border-[#c7c4d8]/15 bg-surface-container-low p-4 sm:grid-cols-[1fr_1fr_auto]"
          >
            <div className="flex flex-col gap-1">
              <label className="font-mono text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">
                Travel date
              </label>
              <div className="relative">
                <CalendarDays className="pointer-events-none absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-brand-600" />
                <input
                  type="date"
                  value={dateInput}
                  onChange={(e) => setDateInput(e.target.value)}
                  className="w-full rounded-lg border-none bg-surface-container-lowest py-2.5 pl-9 pr-3 font-mono text-sm tabular-nums text-on-surface outline-none transition-all focus:ring-2 focus:ring-brand-600/20"
                />
              </div>
            </div>

            <div className="flex flex-col gap-1">
              <label className="font-mono text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">
                Origin / Route
              </label>
              <div className="relative">
                <MapPin className="pointer-events-none absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-brand-600" />
                <input
                  type="text"
                  value={routeInput}
                  onChange={(e) => setRouteInput(e.target.value)}
                  placeholder="Central Hub..."
                  className="w-full rounded-lg border-none bg-surface-container-lowest py-2.5 pl-9 pr-3 text-sm text-on-surface placeholder:text-on-surface-variant/40 outline-none transition-all focus:ring-2 focus:ring-brand-600/20"
                />
              </div>
            </div>

            <div className="flex items-end">
              <button
                type="submit"
                className="flex w-full items-center justify-center gap-2 rounded-lg bg-brand-600 px-5 py-2.5 font-mono text-[11px] font-bold uppercase tracking-wider text-white transition-all hover:bg-brand-700 active:translate-y-px sm:w-auto"
              >
                <Search className="h-3.5 w-3.5" />
                Search
              </button>
            </div>
          </form>

          {/* Board header */}
          <div className="flex items-center justify-between px-1">
            <span className="font-mono text-[11px] font-black uppercase tracking-widest text-on-surface/40">
              Transit Arrivals Board
            </span>
            <span className="flex items-center gap-1.5 font-mono text-[11px] font-bold uppercase text-accent-600">
              <span className="relative flex h-2 w-2">
                <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-accent-500 opacity-75" />
                <span className="relative inline-flex h-2 w-2 rounded-full bg-accent-500" />
              </span>
              Live status
            </span>
          </div>

          {/* Schedule list */}
          <div className={cn("space-y-3", isFetching && !isLoading && "opacity-60 transition-opacity")}>
            {isLoading ? (
              Array.from({ length: 4 }).map((_, i) => <SkeletonRow key={i} />)
            ) : schedules.length === 0 ? (
              <EmptyState />
            ) : (
              schedules.map((schedule) => (
                <ScheduleRow key={schedule.id} schedule={schedule} />
              ))
            )}
          </div>

          {/* Pagination */}
          {meta && meta.total_pages > 1 && (
            <div className="flex items-center justify-between border-t border-[#c7c4d8]/15 pt-4">
              <button
                onClick={() => goToPage(meta.current_page - 1)}
                disabled={meta.current_page <= 1}
                className="inline-flex items-center gap-1 rounded-lg px-3 py-1.5 font-mono text-xs font-semibold text-on-surface-variant transition-colors hover:bg-surface-container-low disabled:pointer-events-none disabled:opacity-30"
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
                className="inline-flex items-center gap-1 rounded-lg px-3 py-1.5 font-mono text-xs font-semibold text-on-surface-variant transition-colors hover:bg-surface-container-low disabled:pointer-events-none disabled:opacity-30"
              >
                Next
                <ChevronRight className="h-3.5 w-3.5" />
              </button>
            </div>
          )}
        </div>

        {/* Right panel — 40% */}
        <div className="w-full space-y-5 lg:w-[40%]">
          {/* System Map */}
          <div className="space-y-3">
            <h2 className="font-mono text-[12px] font-black uppercase tracking-[0.15em] text-on-surface/40">
              System Map
            </h2>
            <SystemMap />
          </div>

          {/* Next Arrival Timeline */}
          <div className="space-y-3">
            <h2 className="font-mono text-[12px] font-black uppercase tracking-[0.15em] text-on-surface/40">
              Next Departure
            </h2>
            <RouteTimeline schedule={nextDeparture} />
          </div>

          {/* Capacity Bento */}
          <div className="space-y-3">
            <h2 className="font-mono text-[12px] font-black uppercase tracking-[0.15em] text-on-surface/40">
              Capacity Overview
            </h2>
            {isLoading ? (
              <div className="grid grid-cols-2 gap-3">
                {Array.from({ length: 4 }).map((_, i) => (
                  <div key={i} className={cn("rounded-xl bg-surface-container-lowest p-4", i === 2 && "col-span-2")}>
                    <div className="h-2 w-16 animate-pulse rounded bg-surface-container-low" />
                    <div className="mt-2 h-5 w-10 animate-pulse rounded bg-surface-container-low" />
                  </div>
                ))}
              </div>
            ) : (
              <CapacityBento schedules={schedules} />
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

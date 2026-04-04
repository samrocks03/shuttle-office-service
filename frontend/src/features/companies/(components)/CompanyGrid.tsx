"use client";

import { useState } from "react";
import { Building2, MapPin, ChevronLeft, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";
import { useCompanies } from "../(queries)/queries";

function CompanyCard({ company }: { company: ICompanyResource }) {
  const a = company.attributes;

  return (
    <div className="group rounded-2xl border border-transparent bg-surface-container-lowest p-6 transition-all hover:border-[#c7c4d8]/20 hover:shadow-sm">
      <div className="mb-4 flex h-11 w-11 items-center justify-center rounded-xl bg-brand-600/10">
        <Building2 className="h-5 w-5 text-brand-600" />
      </div>
      <h3 className="font-semibold text-on-surface">{a.name}</h3>
      {a.location && (
        <div className="mt-2 flex items-center gap-1.5 text-sm text-on-surface-variant">
          <MapPin className="h-3 w-3 shrink-0" />
          <span className="truncate">{a.location}</span>
        </div>
      )}
    </div>
  );
}

function SkeletonCard() {
  return (
    <div className="rounded-2xl bg-surface-container-lowest p-6">
      <div className="mb-4 h-11 w-11 animate-pulse rounded-xl bg-surface-container-low" />
      <div className="h-4 w-32 animate-pulse rounded bg-surface-container-low" />
      <div className="mt-3 h-3 w-24 animate-pulse rounded bg-surface-container-low" />
    </div>
  );
}

export function CompanyGrid() {
  const [page, setPage] = useState(1);
  const { data, isLoading, isFetching } = useCompanies(page);

  const companies = data?.data ?? [];
  const meta = data?.meta;

  return (
    <div className="mx-auto max-w-7xl px-6 py-10">
      {/* Header */}
      <div className="mb-8">
        <p className="mb-2 font-mono text-[10px] uppercase tracking-widest text-on-surface-variant">
          Partner network
        </p>
        <h1 className="text-3xl font-black tracking-tight text-on-surface">
          Companies
        </h1>
        <p className="mt-2 max-w-lg text-on-surface-variant">
          Organizations using Shuttle Office for their employee commute infrastructure.
        </p>
      </div>

      {/* Grid */}
      <div className={cn(
        "grid gap-4 sm:grid-cols-2 lg:grid-cols-3",
        isFetching && !isLoading && "opacity-60 transition-opacity"
      )}>
        {isLoading
          ? Array.from({ length: 6 }).map((_, i) => <SkeletonCard key={i} />)
          : companies.length === 0
            ? (
                <div className="col-span-full flex flex-col items-center justify-center py-20 text-center">
                  <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-surface-container-low">
                    <Building2 className="h-7 w-7 text-on-surface-variant/40" />
                  </div>
                  <h3 className="mt-4 font-semibold text-on-surface">No companies yet</h3>
                  <p className="mt-1 max-w-xs text-sm text-on-surface-variant">
                    Partner companies will appear here once they join the platform.
                  </p>
                </div>
              )
            : companies.map((company) => (
                <CompanyCard key={company.id} company={company} />
              ))
        }
      </div>

      {/* Pagination */}
      {meta && meta.total_pages > 1 && (
        <div className="mt-8 flex items-center justify-between border-t border-[#c7c4d8]/15 pt-4">
          <button
            onClick={() => setPage((p) => p - 1)}
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
            onClick={() => setPage((p) => p + 1)}
            disabled={meta.current_page >= meta.total_pages}
            className="inline-flex items-center gap-1 rounded-lg px-3 py-1.5 font-mono text-xs font-semibold text-on-surface-variant transition-colors hover:bg-surface-container-low disabled:opacity-30 disabled:pointer-events-none"
          >
            Next
            <ChevronRight className="h-3.5 w-3.5" />
          </button>
        </div>
      )}
    </div>
  );
}

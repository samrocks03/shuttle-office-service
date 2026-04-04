import { Skeleton } from "@/components/ui/skeleton";

interface ILoadingShimmerProps {
  variant: "card" | "table" | "form" | "stats";
  count?: number;
}

export function LoadingShimmer({ variant, count = 3 }: ILoadingShimmerProps) {
  const items = Array.from({ length: count }, (_, i) => i);

  switch (variant) {
    case "card":
      return (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {items.map((i) => (
            <div key={i} className="rounded-lg border p-4 space-y-3">
              <Skeleton className="h-5 w-3/4" />
              <Skeleton className="h-4 w-1/2" />
              <Skeleton className="h-4 w-1/3" />
            </div>
          ))}
        </div>
      );
    case "table":
      return (
        <div className="space-y-2">
          <Skeleton className="h-10 w-full" />
          {items.map((i) => (
            <Skeleton key={i} className="h-12 w-full" />
          ))}
        </div>
      );
    case "form":
      return (
        <div className="space-y-4 max-w-md">
          {items.map((i) => (
            <div key={i} className="space-y-2">
              <Skeleton className="h-4 w-20" />
              <Skeleton className="h-10 w-full" />
            </div>
          ))}
          <Skeleton className="h-10 w-full" />
        </div>
      );
    case "stats":
      return (
        <div className="grid gap-4 grid-cols-2 lg:grid-cols-4">
          {Array.from({ length: 4 }, (_, i) => (
            <div key={i} className="rounded-lg border p-4 space-y-2">
              <Skeleton className="h-4 w-16" />
              <Skeleton className="h-8 w-12" />
            </div>
          ))}
        </div>
      );
  }
}

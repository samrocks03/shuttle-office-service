import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";

export const scheduleKeys = {
  all: ["schedules"] as const,
  list: (filters: IScheduleFilters) => ["schedules", "list", filters] as const,
};

export function useSchedules(filters: IScheduleFilters) {
  return useQuery({
    queryKey: scheduleKeys.list(filters),
    queryFn: () =>
      apiClient.get<IApiResponse<IScheduleResource[]>>("/api/v1/schedules", {
        params: {
          page: filters.page,
          per_page: filters.per_page,
          date: filters.date,
          start_point: filters.start_point,
        },
      }),
    staleTime: 60 * 1000,
    placeholderData: keepPreviousData,
  });
}

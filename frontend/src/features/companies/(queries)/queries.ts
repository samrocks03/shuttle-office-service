import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";

export const companyKeys = {
  all: ["companies"] as const,
  list: (page: number) => ["companies", "list", page] as const,
};

export function useCompanies(page: number = 1) {
  return useQuery({
    queryKey: companyKeys.list(page),
    queryFn: () =>
      apiClient.get<IApiResponse<ICompanyResource[]>>("/api/v1/companies", {
        params: { page, per_page: 12 },
      }),
    staleTime: 2 * 60 * 1000,
    placeholderData: keepPreviousData,
  });
}

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";

export const authKeys = {
  user: ["user", "profile"] as const,
  companies: ["companies", "list"] as const,
  companiesSearch: (search: string) => ["companies", "search", search] as const,
};

export function useLoginMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: ILoginRequest) =>
      apiClient.post<ILoginResponse>("/api/auth/login", data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: authKeys.user });
    },
  });
}

export function useRegisterMutation() {
  return useMutation({
    mutationFn: (data: IRegisterRequest) =>
      apiClient.post<IRegisterResponse>("/api/v1/register", data),
  });
}

export function useLogoutMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: () => apiClient.delete("/api/auth/logout"),
    onSuccess: () => {
      queryClient.clear();
      window.location.replace("/login");
    },
  });
}

export function useCompaniesSearch(search: string) {
  return useQuery({
    queryKey: authKeys.companiesSearch(search),
    queryFn: () =>
      apiClient.get<IApiResponse<ICompanyResource[]>>("/api/v1/companies", {
        params: { search: search || undefined, per_page: 10 },
      }),
    staleTime: 2 * 60 * 1000,
    placeholderData: keepPreviousData,
  });
}

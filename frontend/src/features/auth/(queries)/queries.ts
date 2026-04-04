import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";

export const authKeys = {
  user: ["user", "profile"] as const,
  companies: ["companies", "list"] as const,
};

export function useLoginMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: ILoginRequest) =>
      apiClient.post<ILoginResponse>("/api/v1/login", data),
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
    mutationFn: () => apiClient.delete("/api/v1/logout"),
    onSuccess: () => {
      queryClient.clear();
      window.location.href = "/login";
    },
  });
}

export function useCompanies() {
  return useQuery({
    queryKey: authKeys.companies,
    queryFn: () =>
      apiClient.get<IApiResponse<ICompanyOption[]>>("/api/v1/companies"),
    staleTime: 5 * 60 * 1000,
  });
}

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

export const profileKeys = {
  me: ["profile", "me"] as const,
};

async function bff<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
  const response = await fetch(endpoint, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...options.headers,
    },
  });

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({
      success: false,
      errors: { base: [`Request failed with status ${response.status}`] },
    }));
    throw { status: response.status, data: errorData };
  }

  return response.json();
}

export function useProfile() {
  return useQuery({
    queryKey: profileKeys.me,
    queryFn: () => bff<IApiResponse<IProfileResource>>("/api/profile"),
    staleTime: 5 * 60 * 1000,
  });
}

export function useUpdateProfile() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: IUpdateProfileRequest) =>
      bff<IApiResponse<IProfileResource>>("/api/profile", {
        method: "PATCH",
        body: JSON.stringify(data),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: profileKeys.me });
    },
  });
}

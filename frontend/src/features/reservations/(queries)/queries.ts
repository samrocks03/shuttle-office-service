import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { scheduleKeys } from "@/features/schedules/(queries)/queries";

export const reservationKeys = {
  all: ["reservations"] as const,
  list: (page: number) => ["reservations", "list", page] as const,
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

export function useReservations(page: number = 1) {
  return useQuery({
    queryKey: reservationKeys.list(page),
    queryFn: () =>
      bff<IApiResponse<IReservationResource[]>>(
        `/api/reservations?page=${page}&per_page=10`
      ),
    staleTime: 30 * 1000,
    placeholderData: keepPreviousData,
  });
}

export function useCreateReservation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (scheduleId: number) =>
      bff<IApiResponse<IReservationResource>>("/api/reservations", {
        method: "POST",
        body: JSON.stringify({ reservation: { schedule_id: scheduleId } }),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: reservationKeys.all });
      queryClient.invalidateQueries({ queryKey: scheduleKeys.all });
    },
  });
}

export function useCancelReservation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (uid: string) =>
      bff(`/api/reservations/${uid}`, { method: "DELETE" }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: reservationKeys.all });
      queryClient.invalidateQueries({ queryKey: scheduleKeys.all });
    },
  });
}

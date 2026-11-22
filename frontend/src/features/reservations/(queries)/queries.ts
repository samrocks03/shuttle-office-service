import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { scheduleKeys } from "@/features/schedules/(queries)/queries";
import { savePaymentSession } from "@/features/payments/(queries)/session";

export const reservationKeys = {
  all: ["reservations"] as const,
  list: (page: number) => ["reservations", "list", page] as const,
  detail: (uid: string) => ["reservations", "detail", uid] as const,
};

export type BffError = { status: number; data: { errors?: { base?: string[] }; error_key?: string } };

/** The Rails locale message for a failed request; never the gateway's own error text. */
export function bffErrorMessage(error: unknown, fallback = "Something went wrong. Please try again.") {
  const base = (error as BffError | null)?.data?.errors?.base;
  return base?.[0] ?? fallback;
}

export async function bff<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
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

export function useReservation(uid: string) {
  return useQuery({
    queryKey: reservationKeys.detail(uid),
    queryFn: () => bff<IApiResponse<IReservationResource>>(`/api/reservations/${uid}`),
  });
}

export function useCreateReservation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (scheduleId: number) =>
      bff<ICreateReservationResponse>("/api/reservations", {
        method: "POST",
        body: JSON.stringify({ reservation: { schedule_id: scheduleId } }),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: reservationKeys.all });
      queryClient.invalidateQueries({ queryKey: scheduleKeys.all });
    },
  });
}

/**
 * Books a ride. A free ride is confirmed at once (`onConfirmed`); a paid one holds the seat and
 * goes straight to the checkout for it.
 */
export function useBookRide() {
  const router = useRouter();
  const create = useCreateReservation();

  const book = (scheduleId: number, onConfirmed: () => void) =>
    create.mutate(scheduleId, {
      onSuccess: (res) => {
        const reservation = res.data.attributes;
        if (reservation.status === "pending_payment" && res.payment) {
          savePaymentSession(reservation.uid, res.payment);
          router.push(`/employee/reservations/${reservation.uid}/pay`);
          return;
        }
        onConfirmed();
      },
    });

  return { book, create };
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

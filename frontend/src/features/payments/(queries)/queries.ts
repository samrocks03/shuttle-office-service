import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { bff, reservationKeys, type BffError } from "@/features/reservations/(queries)/queries";
import { savePaymentSession } from "./session";

export { clearPaymentSession, readPaymentSession, savePaymentSession } from "./session";

const POLL_MS = 1500;
// After this many answers that still say pending, poll less often: each poll makes Rails sync
// with Hyperswitch. 20 polls at 1.5 s is about 30 s.
const FAST_POLLS = 20;
const SLOW_POLL_MS = 5000;
// A failed read is tried this many more times (with TanStack's backoff) before it counts as failed.
const MAX_RETRIES = 2;
// These will not fix themselves by asking again.
const NO_RETRY_STATUSES = [401, 403, 404];

export function errorStatus(error: unknown): number | undefined {
  return (error as BffError | null)?.status;
}

export const paymentKeys = {
  status: (uid: string) => ["reservations", "payment", uid] as const,
};

/**
 * Where the reservation's payment stands. With `poll`, it is re-read every 1.5 s (5 s after about
 * 30 s) while the reservation is still pending_payment. Polling stops on a final status, when the
 * component unmounts, and when a read fails (after a few retries, or at once on 401/403/404); the
 * caller shows the error and can call `refetch` to start again. The page only shows what Rails
 * says; it never decides that a ride is paid.
 */
export function usePaymentStatus(uid: string, { poll = false }: { poll?: boolean } = {}) {
  return useQuery({
    queryKey: paymentKeys.status(uid),
    queryFn: () => bff<IApiResponse<IReservationPaymentStatus>>(`/api/reservations/${uid}/payment`),
    retry: (failureCount, error) =>
      !NO_RETRY_STATUSES.includes(errorStatus(error) ?? 0) && failureCount < MAX_RETRIES,
    refetchInterval: (query) => {
      // TanStack keeps the last data after a failed read, so check the error first.
      if (!poll || query.state.status === "error") return false;
      if (query.state.data?.data.status !== "pending_payment") return false;
      return query.state.dataUpdateCount > FAST_POLLS ? SLOW_POLL_MS : POLL_MS;
    },
    refetchIntervalInBackground: false,
    staleTime: 0,
  });
}

/** Starts a new payment after the last one failed or was cancelled; keeps the new session. */
export function useRetryPayment(uid: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: () =>
      bff<IApiResponse<IPaymentSession>>(`/api/reservations/${uid}/payment`, { method: "POST" }),
    onSuccess: (res) => {
      savePaymentSession(uid, res.data);
      queryClient.invalidateQueries({ queryKey: paymentKeys.status(uid) });
      queryClient.invalidateQueries({ queryKey: reservationKeys.all });
    },
  });
}

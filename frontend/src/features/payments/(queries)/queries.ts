import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { bff, reservationKeys } from "@/features/reservations/(queries)/queries";
import { savePaymentSession } from "./session";

export { clearPaymentSession, readPaymentSession, savePaymentSession } from "./session";

const POLL_MS = 1500;

export const paymentKeys = {
  status: (uid: string) => ["reservations", "payment", uid] as const,
};

/**
 * Where the reservation's payment stands. With `poll`, it is re-read every 1.5 s while the
 * reservation is still pending_payment; polling stops on a final status or when the component
 * unmounts. The page only shows what Rails says; it never decides that a ride is paid.
 */
export function usePaymentStatus(uid: string, { poll = false }: { poll?: boolean } = {}) {
  return useQuery({
    queryKey: paymentKeys.status(uid),
    queryFn: () => bff<IApiResponse<IReservationPaymentStatus>>(`/api/reservations/${uid}/payment`),
    refetchInterval: (query) =>
      poll && query.state.data?.data.status === "pending_payment" ? POLL_MS : false,
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

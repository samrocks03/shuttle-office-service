/** GET /reservations/:uid/payment */
interface IReservationPaymentStatus {
  status: ReservationStatus;
  /** Latest Hyperswitch payment status, e.g. succeeded, failed, requires_payment_method. */
  payment_status: string | null;
  connector: string | null;
  hold_expires_at: string | null;
}

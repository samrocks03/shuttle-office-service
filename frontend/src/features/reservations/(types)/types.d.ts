interface IReservationUser {
  uid: string;
  first_name: string;
  last_name: string;
}

interface IReservationSchedule {
  uid: string;
  start_point: string;
  arrival_time: string;
  departure_time: string;
  date: string;
  company_name: string;
}

type ReservationStatus = "confirmed" | "pending_payment" | "cancelled" | "expired";

interface IReservationFare {
  amount_minor: number;
  currency: string;
  distance_km: number | null;
  slab_label: string | null;
}

/** Latest refund across the reservation's payments. */
interface IReservationRefund {
  status: "pending" | "succeeded" | "failed" | (string & {});
  amount_minor: number;
  reason: string | null;
}

interface IReservationAttributes {
  uid: string;
  status: ReservationStatus;
  /** Set only while a paid seat is held; the seat is released when it passes. */
  hold_expires_at: string | null;
  /** Fare snapshot for a paid booking; null for a free one. */
  fare: IReservationFare | null;
  /** Latest refund, or null when nothing was refunded. */
  refund: IReservationRefund | null;
  created_at: string;
  updated_at: string;
  user: IReservationUser;
  schedule: IReservationSchedule;
}

interface IReservationResource {
  id: string;
  type: "reservation";
  attributes: IReservationAttributes;
}

interface ICreateReservationRequest {
  reservation: {
    schedule_id: number;
  };
}

/** What the browser needs to open the Hyperswitch checkout for a held seat. */
interface IPaymentSession {
  client_secret: string;
  publishable_key: string;
}

/** POST /reservations: a paid booking also returns the payment session at the top level. */
interface ICreateReservationResponse extends IApiResponse<IReservationResource> {
  payment?: IPaymentSession;
}

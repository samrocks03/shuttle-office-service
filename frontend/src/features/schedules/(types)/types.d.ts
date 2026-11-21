type TFareUnavailableReason = "no_city" | "no_stops" | "no_distance" | "no_fare_table";

interface IScheduleFare {
  amount_minor: number;
  currency: string;
  distance_km: number;
  slab_label: string;
}

interface IScheduleAttributes {
  uid: string;
  start_point: string;
  date: string;
  departure_time: string;
  arrival_time: string;
  available_seats: number;
  bus_uid?: string;
  bus_number?: string;
  bus_capacity?: number;
  company_name?: string;
  company_uid?: string;
  booked_by_current_user?: boolean;
  /** True when booking this schedule is paid; fare UI is shown only then. */
  payments_enabled: boolean;
  fare: IScheduleFare | null;
  fare_unavailable_reason: TFareUnavailableReason | null;
  bus_service_class?: "non_ac" | "ac" | null;
}

interface IScheduleResource {
  id: string;
  type: "schedule";
  attributes: IScheduleAttributes;
}

interface IScheduleFilters {
  date?: string;
  start_point?: string;
  per_page?: number;
  page?: number;
}

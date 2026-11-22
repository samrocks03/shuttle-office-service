interface ICityAttributes {
  uid: string;
  name: string;
  country_code: string;
  currency: string;
  time_zone: string;
  distance_provider: string;
  payments_enabled: boolean;
  stops_count: number;
}

interface ICityResource {
  id: string;
  type: "city";
  attributes: ICityAttributes;
}

interface IStopAttributes {
  uid: string;
  name: string;
  kind: "pickup" | "office";
  latitude: number;
  longitude: number;
  active: boolean;
  osm_ref: string | null;
  city_uid: string;
}

interface IStopResource {
  id: string;
  type: "stop";
  attributes: IStopAttributes;
}

interface IStopSummary {
  uid: string;
  name: string;
  kind: "pickup" | "office";
}

interface IStopDistanceAttributes {
  uid: string;
  from_stop: IStopSummary;
  to_stop: IStopSummary;
  computed_km: number | null;
  computed_minutes: number | null;
  source: string | null;
  computed_at: string | null;
  override_km: number | null;
  override_reason: string | null;
  overridden_by_name: string | null;
  /** The override when set, else the computed km; null when the pair has neither. */
  effective_km: number | null;
  /** No effective km: bookings on this pair get no fare until it is routed or overridden. */
  unrouted: boolean;
}

interface IStopDistanceResource {
  id: string;
  type: "stop_distance";
  attributes: IStopDistanceAttributes;
}

interface IStopDistanceList extends IApiResponse<IStopDistanceResource[]> {
  meta: IApiResponse<unknown>["meta"] & { total_count: number; max_rows: number };
}

interface IFareSlab {
  up_to_km: number;
  amount_minor: number;
}

interface IFareTableAttributes {
  uid: string;
  city_uid: string;
  service_class: "non_ac" | "ac";
  currency: string;
  policy: string;
  effective_from: string;
  active: boolean;
  /** Beyond the last slab, each further `step_km` adds `step_amount_minor`. */
  step_km: number | null;
  step_amount_minor: number | null;
  slabs: IFareSlab[];
}

interface IFareTableResource {
  id: string;
  type: "fare_table";
  attributes: IFareTableAttributes;
}

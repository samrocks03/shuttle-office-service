import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { bff } from "@/features/reservations/(queries)/queries";

export const routingKeys = {
  cities: ["routing", "cities"] as const,
  city: (uid: string) => ["routing", "city", uid] as const,
  stops: (cityUid: string) => ["routing", "stops", cityUid] as const,
  distances: (cityUid: string) => ["routing", "distances", cityUid] as const,
  fareTables: (cityUid: string) => ["routing", "fare_tables", cityUid] as const,
};

// Every call below goes to a Next route handler, which adds the JWT and forwards to Rails.
const path = (...segments: string[]) => `/api/${segments.map(encodeURIComponent).join("/")}`;

export function useCities() {
  return useQuery({
    queryKey: routingKeys.cities,
    queryFn: () => bff<IApiResponse<ICityResource[]>>(path("cities")),
  });
}

export function useCity(uid: string) {
  return useQuery({
    queryKey: routingKeys.city(uid),
    queryFn: () => bff<IApiResponse<ICityResource>>(path("cities", uid)),
  });
}

export function useStops(cityUid: string) {
  return useQuery({
    queryKey: routingKeys.stops(cityUid),
    queryFn: () => bff<IApiResponse<IStopResource[]>>(path("cities", cityUid, "stops")),
  });
}

export function useStopDistances(cityUid: string) {
  return useQuery({
    queryKey: routingKeys.distances(cityUid),
    queryFn: () => bff<IStopDistanceList>(`${path("stop_distances")}?city_uid=${encodeURIComponent(cityUid)}`),
  });
}

export function useFareTables(cityUid: string) {
  return useQuery({
    queryKey: routingKeys.fareTables(cityUid),
    queryFn: () => bff<IApiResponse<IFareTableResource[]>>(`${path("fare_tables")}?city_uid=${encodeURIComponent(cityUid)}`),
  });
}

interface IOverrideInput {
  /** `null` clears the override. */
  override_km: number | null;
  override_reason?: string | null;
}

export function useSetOverride(cityUid: string, distanceUid: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: IOverrideInput) =>
      bff<IApiResponse<IStopDistanceResource>>(path("stop_distances", distanceUid), {
        method: "PATCH",
        body: JSON.stringify(input),
      }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: routingKeys.distances(cityUid) }),
  });
}

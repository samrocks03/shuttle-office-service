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

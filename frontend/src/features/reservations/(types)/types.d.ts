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

interface IReservationAttributes {
  uid: string;
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

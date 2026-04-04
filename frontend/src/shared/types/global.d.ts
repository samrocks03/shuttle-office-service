interface IApiResponse<T> {
  success: boolean;
  data: T;
  message: string;
  meta?: IPaginationMeta;
}

interface IApiError {
  success: false;
  errors: {
    base: string[];
  };
}

interface IPaginationMeta {
  current_page: number;
  per_page: number;
  total_count: number;
  total_pages: number;
}

interface IUser {
  id: string;
  uid: string;
  first_name: string;
  last_name: string;
  email: string;
  phone_number: string;
  company_id: number;
  role_id: number;
  role_type: number;
  company: {
    id: number;
    uid: string;
    name: string;
  };
}

interface ITokenPayload {
  user_id: number;
  user_uid: string;
  role_type: number;
  company_id: number;
  exp?: number;
}

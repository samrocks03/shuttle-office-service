interface IProfileAttributes {
  uid: string;
  first_name: string;
  last_name: string;
  phone_number: string;
  email: string;
  role_name: string;
  role_type: string;
  company_name: string;
  company_uid: string;
  created_at: string;
  updated_at: string;
}

interface IProfileResource {
  id: string;
  type: "user";
  attributes: IProfileAttributes;
}

interface IUpdateProfileRequest {
  user: {
    first_name?: string;
    last_name?: string;
    phone_number?: string;
    email?: string;
  };
}

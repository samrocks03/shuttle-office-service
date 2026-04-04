interface ILoginRequest {
  user: {
    email: string;
    password: string;
  };
}

interface ILoginResponse {
  success: boolean;
  data: {
    user: {
      data: {
        id: string;
        type: string;
        attributes: IUser;
      };
    };
    token: string;
  };
  message: string;
}

interface IRegisterRequest {
  user: {
    first_name: string;
    last_name: string;
    phone_number: string;
    email: string;
    password: string;
    company_id: number;
    role_id?: number;
  };
}

interface IRegisterResponse {
  success: boolean;
  data: {
    user: {
      data: {
        id: string;
        type: string;
        attributes: IUser;
      };
    };
  };
  message: string;
}

interface ICompanyResource {
  id: string;
  type: "company";
  attributes: {
    uid: string;
    name: string;
    location: string;
    created_at: string;
    updated_at: string;
  };
}

interface ICompanyOption {
  id: number;
  uid: string;
  name: string;
}

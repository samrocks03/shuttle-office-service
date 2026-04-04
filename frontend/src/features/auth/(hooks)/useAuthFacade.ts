"use client";

import { useMemo, useCallback, useState } from "react";
import { useRouter } from "next/navigation";
import { useDebounce } from "@/shared/hooks/useDebounce";
import { getDashboardPath } from "@/lib/auth";
import {
  useLoginMutation,
  useRegisterMutation,
  useLogoutMutation,
  useCompaniesSearch,
} from "../(queries)/queries";

interface IUseLoginFacadeReturn {
  login: (data: ILoginRequest) => void;
  isPending: boolean;
  error: string | null;
}

export function useLoginFacade(): IUseLoginFacadeReturn {
  const router = useRouter();
  const mutation = useLoginMutation();

  const error = useMemo(() => {
    if (!mutation.error) return null;
    const err = mutation.error as { status?: number; data?: IApiError };
    if (err.data?.errors?.base?.[0]) return err.data.errors.base[0];
    if (err.status === 401) return "Invalid email or password";
    return "Something went wrong. Please try again.";
  }, [mutation.error]);

  const login = useCallback(
    (data: ILoginRequest) => {
      mutation.mutate(data, {
        onSuccess: (response) => {
          const roleType = response.data.user.data.attributes.role_type;
          const dashboardPath = getDashboardPath(roleType);
          router.push(dashboardPath);
          router.refresh();
        },
      });
    },
    [mutation, router]
  );

  return {
    login,
    isPending: mutation.isPending,
    error,
  };
}

interface IUseRegisterFacadeReturn {
  register: (data: IRegisterRequest) => void;
  isPending: boolean;
  error: string | null;
  companies: ICompanyOption[];
  companiesLoading: boolean;
  onCompanySearch: (search: string) => void;
}

export function useRegisterFacade(): IUseRegisterFacadeReturn {
  const router = useRouter();
  const mutation = useRegisterMutation();

  const [search, setSearch] = useState("");
  const debouncedSearch = useDebounce(search, 300);
  const companiesQuery = useCompaniesSearch(debouncedSearch);

  const error = useMemo(() => {
    if (!mutation.error) return null;
    const err = mutation.error as { status?: number; data?: IApiError };
    if (err.data?.errors?.base?.[0]) return err.data.errors.base[0];
    if (err.status === 409) return "An account with this email already exists";
    return "Registration failed. Please try again.";
  }, [mutation.error]);

  const register = useCallback(
    (data: IRegisterRequest) => {
      mutation.mutate(data, {
        onSuccess: () => {
          router.push("/login?registered=true");
        },
      });
    },
    [mutation, router]
  );

  return {
    register,
    isPending: mutation.isPending,
    error,
    companies: (companiesQuery.data?.data ?? []).map((c) => ({
      id: Number(c.id),
      uid: c.attributes.uid,
      name: c.attributes.name,
    })),
    companiesLoading: companiesQuery.isFetching,
    onCompanySearch: setSearch,
  };
}

interface IUseLogoutFacadeReturn {
  logout: () => void;
  isPending: boolean;
}

export function useLogoutFacade(): IUseLogoutFacadeReturn {
  const mutation = useLogoutMutation();

  return {
    logout: () => mutation.mutate(),
    isPending: mutation.isPending,
  };
}

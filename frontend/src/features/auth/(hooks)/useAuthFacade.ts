"use client";

import { useMemo, useCallback } from "react";
import { useRouter } from "next/navigation";
import {
  useLoginMutation,
  useRegisterMutation,
  useLogoutMutation,
  useCompanies,
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
        onSuccess: () => {
          // Cookie is set by Rails. Redirect to home — proxy routes by role.
          router.push("/");
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
}

export function useRegisterFacade(): IUseRegisterFacadeReturn {
  const router = useRouter();
  const mutation = useRegisterMutation();
  const companiesQuery = useCompanies();

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
    companies: companiesQuery.data?.data ?? [],
    companiesLoading: companiesQuery.isLoading,
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

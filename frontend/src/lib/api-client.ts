const getBaseUrl = (): string => {
  if (typeof window === "undefined") {
    return process.env.INTERNAL_API_URL || "http://localhost:3000";
  }
  return process.env.NEXT_PUBLIC_API_URL || "";
};

interface IRequestOptions extends Omit<RequestInit, "body"> {
  params?: Record<string, string | number | undefined>;
  body?: unknown;
}

async function request<T>(
  endpoint: string,
  options: IRequestOptions = {}
): Promise<T> {
  const { params, body, headers: customHeaders, ...restOptions } = options;

  const url = new URL(`${getBaseUrl()}${endpoint}`);
  if (params) {
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined) {
        url.searchParams.set(key, String(value));
      }
    });
  }

  const headers: HeadersInit = {
    "Content-Type": "application/json",
    Accept: "application/json",
    ...customHeaders,
  };

  // Server-side: forward cookie as Bearer token to Rails
  if (typeof window === "undefined") {
    const { cookies } = await import("next/headers");
    const cookieStore = await cookies();
    const token = cookieStore.get("token")?.value;
    if (token) {
      Object.assign(headers, { Authorization: `Bearer ${token}` });
    }
  }

  const response = await fetch(url.toString(), {
    ...restOptions,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({
      success: false,
      errors: { base: [`Request failed with status ${response.status}`] },
    }));
    throw { status: response.status, data: errorData };
  }

  return response.json();
}

export const apiClient = {
  get: <T>(endpoint: string, options?: IRequestOptions) =>
    request<T>(endpoint, { ...options, method: "GET" }),

  post: <T>(endpoint: string, body: unknown, options?: IRequestOptions) =>
    request<T>(endpoint, { ...options, method: "POST", body }),

  put: <T>(endpoint: string, body: unknown, options?: IRequestOptions) =>
    request<T>(endpoint, { ...options, method: "PUT", body }),

  patch: <T>(endpoint: string, body: unknown, options?: IRequestOptions) =>
    request<T>(endpoint, { ...options, method: "PATCH", body }),

  delete: <T>(endpoint: string, options?: IRequestOptions) =>
    request<T>(endpoint, { ...options, method: "DELETE" }),
};

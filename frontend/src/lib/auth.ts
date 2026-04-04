import { decodeJwt } from "jose";

const COOKIE_NAME = "token";

/**
 * Decode JWT payload without verification (for middleware routing).
 * Middleware runs on the Edge — we decode to read role_type for routing.
 * Actual auth verification happens on Rails when the API is called.
 */
function decodeToken(token: string): ITokenPayload | null {
  try {
    const payload = decodeJwt(token) as unknown as ITokenPayload;
    return payload;
  } catch {
    return null;
  }
}

/**
 * Check if a token is expired based on its exp claim.
 */
function isTokenExpired(token: string): boolean {
  const payload = decodeToken(token);
  if (!payload?.exp) return false;
  return Date.now() >= payload.exp * 1000;
}

/**
 * Role constants matching Rails role_type enum.
 */
const ROLES = {
  EMPLOYEE: 0,
  ADMIN: 1,
  SUPER_ADMIN: 2,
} as const;

/**
 * Map role_type to dashboard path prefix.
 */
function getDashboardPath(roleType: number): string {
  switch (roleType) {
    case ROLES.ADMIN:
      return "/admin";
    case ROLES.SUPER_ADMIN:
      return "/super-admin";
    default:
      return "/employee";
  }
}

export { COOKIE_NAME, decodeToken, isTokenExpired, ROLES, getDashboardPath };

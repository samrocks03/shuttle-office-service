import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { COOKIE_NAME, decodeToken, isTokenExpired, getDashboardPath, ROLES } from "@/lib/auth";

const PUBLIC_ROUTES = ["/", "/schedules", "/companies", "/buses", "/login", "/register"];

function isPublicRoute(pathname: string): boolean {
  return PUBLIC_ROUTES.some(
    (route) => pathname === route || pathname.startsWith(`${route}/`)
  );
}

function isDashboardRoute(pathname: string): boolean {
  return (
    pathname.startsWith("/employee") ||
    pathname.startsWith("/admin") ||
    pathname.startsWith("/super-admin")
  );
}

function roleMatchesPath(roleType: number, pathname: string): boolean {
  switch (roleType) {
    case ROLES.EMPLOYEE:
      return pathname.startsWith("/employee");
    case ROLES.ADMIN:
      return pathname.startsWith("/admin");
    case ROLES.SUPER_ADMIN:
      return pathname.startsWith("/super-admin");
    default:
      return false;
  }
}

export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const token = request.cookies.get(COOKIE_NAME)?.value;

  // Public routes: always allow
  if (isPublicRoute(pathname)) {
    // If logged in and trying to access /login or /register, redirect to dashboard
    if ((pathname === "/login" || pathname === "/register") && token) {
      const payload = decodeToken(token);
      if (payload && !isTokenExpired(token)) {
        const dashboardPath = getDashboardPath(payload.role_type);
        return NextResponse.redirect(new URL(dashboardPath, request.url));
      }
    }
    return NextResponse.next();
  }

  // Protected routes: require valid token
  if (!token) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("redirect", pathname);
    return NextResponse.redirect(loginUrl);
  }

  // Check token expiry
  if (isTokenExpired(token)) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("expired", "true");
    loginUrl.searchParams.set("redirect", pathname);
    const response = NextResponse.redirect(loginUrl);
    response.cookies.delete(COOKIE_NAME);
    return response;
  }

  // Decode and check role
  const payload = decodeToken(token);
  if (!payload) {
    const loginUrl = new URL("/login", request.url);
    const response = NextResponse.redirect(loginUrl);
    response.cookies.delete(COOKIE_NAME);
    return response;
  }

  // Dashboard routes: verify role matches path
  if (isDashboardRoute(pathname) && !roleMatchesPath(payload.role_type, pathname)) {
    const correctPath = getDashboardPath(payload.role_type);
    return NextResponse.redirect(new URL(correctPath, request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|api/).*)",
  ],
};

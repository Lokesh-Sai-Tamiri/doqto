// Next.js 16: this file replaces middleware.ts. Guards non-auth routes.
// Runs before rendering, so an unauthenticated visitor never sees the dashboard.

import { NextResponse, type NextRequest } from "next/server";

import { COOKIE_NAME } from "@/lib/env";

export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const token = request.cookies.get(COOKIE_NAME)?.value;

  const isPublic =
    pathname === "/login" ||
    pathname.startsWith("/api/login") ||
    pathname.startsWith("/api/logout") ||
    pathname === "/favicon.ico";

  if (!token && !isPublic) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    url.search = "";
    return NextResponse.redirect(url);
  }
  if (token && pathname === "/login") {
    const url = request.nextUrl.clone();
    url.pathname = "/orgs";
    return NextResponse.redirect(url);
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/|static/).*)"],
};

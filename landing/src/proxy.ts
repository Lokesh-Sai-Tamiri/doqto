// Next.js 16: this file replaces middleware.ts.
// Guards /admin with HTTP Basic auth — waitlist emails must not be public.
// Set WAITLIST_ADMIN_PASSWORD in the environment; /admin 404s if unset.

import { NextResponse, type NextRequest } from "next/server";

export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  if (!pathname.startsWith("/admin")) {
    return NextResponse.next();
  }

  const password = process.env.WAITLIST_ADMIN_PASSWORD;
  if (!password) {
    return new NextResponse("Not found", { status: 404 });
  }

  const header = request.headers.get("authorization") ?? "";
  const expected = `Basic ${Buffer.from(`admin:${password}`).toString("base64")}`;
  if (header !== expected) {
    return new NextResponse("Authentication required", {
      status: 401,
      headers: { "WWW-Authenticate": 'Basic realm="Doqto Admin"' },
    });
  }
  return NextResponse.next();
}

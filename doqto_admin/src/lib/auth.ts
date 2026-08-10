// Server-side auth helpers. Reads the admin JWT from an httpOnly cookie.

import { cookies } from "next/headers";
import { redirect } from "next/navigation";

import { COOKIE_NAME } from "./env";

export async function readToken(): Promise<string | null> {
  const jar = await cookies();
  return jar.get(COOKIE_NAME)?.value ?? null;
}

export async function requireToken(): Promise<string> {
  const token = await readToken();
  if (!token) redirect("/login");
  return token;
}

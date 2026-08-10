// Typed server-side fetch helpers against the FastAPI backend.
// All calls here auto-attach the admin JWT read from the httpOnly cookie.

import "server-only";

import { readToken } from "./auth";
import { API_BASE_URL } from "./env";
import { humanizeError } from "./errors";
import type { Organization, OrgStatus, TokenPair } from "./types";

export class ApiError extends Error {
  status: number;
  detail: string;
  constructor(status: number, detail: string) {
    super(humanizeError(detail, status));
    this.status = status;
    this.detail = detail;
  }
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = await readToken();
  const headers = new Headers(init.headers);
  headers.set("Content-Type", "application/json");
  if (token) headers.set("Authorization", `Bearer ${token}`);

  let res: Response;
  try {
    res = await fetch(`${API_BASE_URL}${path}`, {
      ...init,
      headers,
      cache: "no-store",
    });
  } catch {
    throw new ApiError(0, "network_unreachable");
  }

  if (!res.ok) {
    let detail = "unknown_error";
    try {
      const body = (await res.json()) as { detail?: string | unknown };
      if (typeof body.detail === "string") detail = body.detail;
    } catch {
      // body wasn't JSON
    }
    throw new ApiError(res.status, detail);
  }

  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

// ---------- Admin endpoints ----------

export async function adminLogin(
  email: string,
  password: string,
): Promise<TokenPair> {
  return request<TokenPair>("/api/v1/admin/auth/login", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
}

export async function listOrgs(
  status: OrgStatus | "all" = "pending",
): Promise<Organization[]> {
  return request<Organization[]>(`/api/v1/admin/orgs?status=${status}`);
}

export async function approveOrg(
  id: string,
  notes?: string,
): Promise<Organization> {
  return request<Organization>(`/api/v1/admin/orgs/${id}/verify`, {
    method: "PATCH",
    body: JSON.stringify({ notes: notes || null }),
  });
}

export async function rejectOrg(id: string, reason: string): Promise<Organization> {
  return request<Organization>(`/api/v1/admin/orgs/${id}/reject`, {
    method: "PATCH",
    body: JSON.stringify({ reason }),
  });
}

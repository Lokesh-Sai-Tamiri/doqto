// Centralized env access. Server-only — never import this into a client component.

export const API_BASE_URL = process.env.API_BASE_URL ?? "http://localhost:8000";
export const COOKIE_NAME = "dox2dox_admin_token";
export const COOKIE_MAX_AGE_SECONDS = 60 * 60 * 24 * 7; // 7 days, matches refresh TTL

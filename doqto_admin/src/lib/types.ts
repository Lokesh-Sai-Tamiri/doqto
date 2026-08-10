// Mirrors backend Pydantic response schemas.

export type OrgStatus = "pending" | "active" | "suspended";

export interface Organization {
  id: string;
  name: string;
  address: string | null;
  city: string | null;
  state: string | null;
  practice_type: string | null;
  invite_code: string;
  status: OrgStatus;
  review_notes: string | null;
  verified_at: string | null;
  created_at: string;
  member_count: number;
}

export interface TokenPair {
  access_token: string;
  refresh_token: string;
  is_registered: boolean;
}

export interface ApiError {
  detail: string;
}

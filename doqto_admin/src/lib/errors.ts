// Backend error codes → admin-facing copy.
// Same philosophy as the mobile app: calm, clinical, actionable, no HTTP codes.

const BY_CODE: Record<string, string> = {
  invalid_credentials: "Email or password is incorrect.",
  rejection_reason_required: "Please provide a reason for rejecting this organization.",
  super_admin_required: "Only platform administrators can perform this action.",
  org_not_found: "We couldn't find that organization.",
  org_suspended: "This organization is already suspended.",
  session_revoked: "Your session ended. Please sign in again.",
  missing_authorization: "Please sign in to continue.",
  user_not_found: "Your account no longer exists. Please contact support.",
};

export function humanizeError(detail: string | undefined | null, status?: number) {
  if (detail && BY_CODE[detail]) return BY_CODE[detail];
  switch (status) {
    case 400:
      return "We couldn't process that. Please double-check and try again.";
    case 401:
      return "Please sign in again to continue.";
    case 403:
      return "You don't have permission to do that.";
    case 404:
      return "We couldn't find what you were looking for.";
    case 429:
      return "Too many requests — please slow down and try again.";
    case undefined:
    case null:
    case 0:
      return "Couldn't reach the server. Check your connection and try again.";
  }
  return "Something went wrong. Please try again.";
}

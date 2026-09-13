# Sign-up, and adding a phone later

## One door

There is no separate "Create an account". The phone number decides:

```
Login → phone → OTP ─┬─ number known   → signed in
                     └─ number unknown → Your details → Choose your plan → app
```

`POST /auth/verify-otp` already returns `is_registered`; the app routes on it.
Social sign-in (not built yet) joins at the same point: once the provider has
verified the person, a new account lands on **Your details**.

Your details is unreachable without that verified session — the router sends a
signed-out user back to Login.

## Your details

Required fields are marked `*`: first name, last name, specialty, NPI. No
helper texts. The one conditional line under NPI — "Several clinicians share
that name…" — stays, because it tells the user what to do next.

**Phone** appears only for an account that has none, i.e. social sign-up. It
is optional, so it carries no `*`. Rules:

| State | Continue |
|---|---|
| Empty | allowed |
| Typed, not verified | blocked — "Verify this number, or clear it to skip." |
| Verified by OTP | allowed |

Editing the number (or its country) after verifying starts verification over.
Clearing it makes it optional again.

Today every account is created by phone, so nobody sees this field until social
sign-in ships. It is built and tested against the contract below.

## Backend contract — NOT YET IMPLEMENTED

The sign-in OTP cannot be reused: `verify-otp` signs you in **as** that number,
which would swap the social account for a different (possibly new) one. Adding
a phone to the signed-in account needs two authenticated endpoints:

### `POST /api/v1/users/me/phone`

```json
{ "phone": "+12015550123" }
```

Texts a 6-digit code to `phone`. `204` on success.

- `409` if the number already belongs to another account — say so *before*
  sending an SMS.
- Same rate limits as `request-otp`.

### `POST /api/v1/users/me/phone/verify`

```json
{ "phone": "+12015550123", "code": "123456" }
```

On success, sets `phone` on the current user and returns the full `User` (same
shape as `GET /users/me`). `400` for a wrong or expired code. Must not issue new
tokens or change which account is signed in.

### Also needed for social accounts

`User.phone` must be allowed to be null or absent. The app already reads a
missing phone as empty.

## Practice location

`POST /auth/register` takes only `full_name`, `specialty`, `npi_number` and
silently drops anything else. The city/state from the NPI registry are saved
with `PATCH /users/me` straight after, best-effort — a failure there never
blocks registration.

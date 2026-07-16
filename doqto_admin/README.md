# Doqto Admin

Super-admin console for the Doqto platform. Approves or rejects new
organizations from the mobile app.

## Quick start

```bash
cp .env.example .env.local
npm install
npm run dev   # http://localhost:3001
```

The backend must be running separately (`doqto_backend/` on port 8000). CORS
is already configured to allow `http://localhost:3001`.

## Login

Default dev credentials (seeded from the backend `.env`):

- email: `admin@doqto.app`
- password: `ChangeMe123!`

Rotate both values in `doqto_backend/.env` (`SUPER_ADMIN_EMAIL`,
`SUPER_ADMIN_PASSWORD`) and re-run the `0005_seed_admin_creds` migration
to change them.

## Architecture

- **Next.js 16 App Router** with TypeScript and Tailwind CSS v4.
- **Auth:** POST `/api/login` calls the FastAPI `/api/v1/admin/auth/login`
  endpoint and stores the JWT in an httpOnly cookie. The `proxy.ts` file
  (Next.js 16's replacement for `middleware.ts`) redirects unauthenticated
  visitors to `/login`.
- **API calls:** every backend request goes through `src/lib/api.ts`, which
  auto-attaches the Bearer token from the cookie. Client components never
  call the backend directly; they POST to Next.js route handlers under
  `src/app/api/*` which proxy server-side.
- **Design tokens:** mirror `docs/design.md` on the mobile side. Defined
  once in `src/app/globals.css` under `@theme inline`. Never inline hex
  colors anywhere else in the app.

## Running alongside the marketing site

`landing/` runs on port 3000. This admin panel runs on port 3001 (see
`package.json` scripts).

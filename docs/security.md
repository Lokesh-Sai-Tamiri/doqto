
## Encryption key management (pre-production TODO)

`MESSAGE_ENCRYPTION_KEY` is currently a single static AES-256-GCM key in the
environment. Before signing any BAA / going to production:

1. Move the key to a KMS (AWS KMS) — envelope encryption: KMS master key wraps
   per-deployment data keys; app only ever sees the data key.
2. Add key rotation: version-prefix ciphertexts (`v1:` …) so old messages
   decrypt with the retiring key while new writes use the current one.
3. Consider per-org data keys so one org's compromise can't expose another's.

Message bodies AND voice-note transcripts are AES-256-GCM encrypted at rest
(migration 0008). S3 objects rely on bucket-level SSE, and every `put_object`
also sets `ServerSideEncryption=AES256` explicitly.

## Production transport requirements

In-transit encryption is a config concern — nothing in code enforces it, so
production deployments MUST set:

1. **Postgres**: append `?ssl=require` to `DATABASE_URL`
   (`postgresql+asyncpg://…/doqto?ssl=require`). Prefer `verify-full` with the
   provider CA bundle when available.
2. **Redis**: use a `rediss://` URL (TLS) with a strong password. The local
   compose `redis://:password@` form is dev-only.
3. **HTTP/WebSocket**: terminate TLS in front of uvicorn (ALB/nginx/Caddy);
   the app must never be reachable over plain `http://`/`ws://` outside local.
   WS auth is auth-frame only — tokens never appear in URLs or proxy logs.

## Deferred items (documented, accepted for now)

- **Audit rows share the request transaction**: a rolled-back request drops
  its audit rows. Coupling audit writes to a separate transaction/outbox is
  deferred until there's an ops story for it.
- **Media checksums**: no application-level checksum on S3 media. AES-GCM
  authenticates text/transcripts; S3 ETag/SSE covers media integrity at rest.
- **Break-glass emergency access**: N/A at current scale (no clinical
  dependence on the system; solo-operator recovery via infra access).
- **Account deletion / PHI purge endpoint**: TODO before public launch —
  message content purge exists (30-day grace crypto-shred of deleted/expired
  messages + S3 disposal), but a full "delete my account and PHI" flow does not.

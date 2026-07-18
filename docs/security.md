
## Encryption key management (pre-production TODO)

`MESSAGE_ENCRYPTION_KEY` is currently a single static AES-256-GCM key in the
environment. Before signing any BAA / going to production:

1. Move the key to a KMS (AWS KMS) — envelope encryption: KMS master key wraps
   per-deployment data keys; app only ever sees the data key.
2. Add key rotation: version-prefix ciphertexts (`v1:` …) so old messages
   decrypt with the retiring key while new writes use the current one.
3. Consider per-org data keys so one org's compromise can't expose another's.

Message bodies AND voice-note transcripts are AES-256-GCM encrypted at rest
(migration 0008). S3 objects rely on bucket-level SSE.

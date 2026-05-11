"""Fake AWS clients used when ENVIRONMENT=local. OTP codes and transcripts are logged, not sent."""

from __future__ import annotations

import logging

log = logging.getLogger("dox2dox.fakes")


class FakeSNSClient:
    async def send_otp(self, phone: str, code: str) -> None:
        log.info("[FAKE SNS] send OTP %s to %s", code, phone)


class FakeTranscribeClient:
    async def start_medical_job(self, *, message_id: str, s3_key: str, specialty: str) -> None:
        log.info("[FAKE TRANSCRIBE] would start job for %s (%s, %s)", message_id, s3_key, specialty)

    async def fetch_transcript(self, message_id: str) -> str:
        return f"[fake transcript for {message_id}] patient follow-up recommended."


class FakeS3Client:
    """Local dev S3 stub. Not for production — upload/get return deterministic fake URLs."""

    _store: dict[str, bytes] = {}

    async def upload_bytes(self, *, key: str, data: bytes, content_type: str) -> None:
        self._store[key] = data
        log.info("[FAKE S3] stored %d bytes at %s (%s)", len(data), key, content_type)

    async def presigned_url(self, *, key: str, expires_in: int) -> str:
        return f"http://localhost:8000/_fake_s3/{key}?ttl={expires_in}"

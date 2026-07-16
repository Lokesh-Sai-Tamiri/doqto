"""Fake AWS clients used when ENVIRONMENT=local. OTP codes and transcripts are logged, not sent."""

from __future__ import annotations

import logging
import os
from pathlib import Path

log = logging.getLogger("doqto.fakes")

_FAKE_S3_DIR = Path(os.environ.get("FAKE_S3_DIR", "/tmp/doqto_fake_s3"))


class FakeSNSClient:
    async def send_otp(self, phone: str, code: str) -> None:
        log.info("[FAKE SNS] send OTP %s to %s", code, phone)


class FakeTranscribeClient:
    async def start_medical_job(self, *, message_id: str, s3_key: str, specialty: str) -> None:
        log.info("[FAKE TRANSCRIBE] would start job for %s (%s, %s)", message_id, s3_key, specialty)

    async def fetch_transcript(self, message_id: str) -> str:
        return ""


class FakeS3Client:
    """Local dev S3 stub. Persists to /tmp so audio survives uvicorn reloads."""

    async def upload_bytes(self, *, key: str, data: bytes, content_type: str) -> None:
        path = _FAKE_S3_DIR / key
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        log.info("[FAKE S3] stored %d bytes at %s (%s)", len(data), key, content_type)

    async def presigned_url(self, *, key: str, expires_in: int) -> str:
        return f"http://localhost:8000/_fake_s3/{key}?ttl={expires_in}"

    @staticmethod
    def read_bytes(key: str) -> bytes | None:
        path = _FAKE_S3_DIR / key
        if path.exists():
            return path.read_bytes()
        return None

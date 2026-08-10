"""Fake AWS clients used when ENVIRONMENT=local. OTP codes and transcripts are logged, not sent."""

from __future__ import annotations

import logging

log = logging.getLogger("doqto.fakes")


class FakeSNSClient:
    async def send_otp(self, phone: str, code: str) -> None:
        log.info("[FAKE SNS] send OTP %s to %s", code, phone)


class FakeTranscribeClient:
    async def start_medical_job(self, *, message_id: str, s3_key: str, specialty: str) -> None:
        log.info("[FAKE TRANSCRIBE] would start job for %s (%s, %s)", message_id, s3_key, specialty)

    async def fetch_transcript(self, message_id: str) -> str:
        return ""

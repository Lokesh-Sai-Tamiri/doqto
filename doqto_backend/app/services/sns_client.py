"""Real AWS SNS client for OTP SMS. Selected outside local (see auth_service._sns).

Log policy: NEVER log the OTP code or the full phone number — this path runs
in staging/production where log lines are retained.
"""

from __future__ import annotations

import logging

import boto3

from app.core.config import settings

log = logging.getLogger("doqto.sns")

_client = None


def _get_client():
    global _client
    if _client is None:
        _client = boto3.client(
            "sns",
            region_name=settings.AWS_REGION,
            # Blank keys → boto3 default chain (ECS task role in prod).
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID or None,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY or None,
        )
    return _client


class RealSNSClient:
    async def send_otp(self, phone: str, code: str) -> None:
        _get_client().publish(
            PhoneNumber=phone,
            Message=f"Your Doqto verification code is {code}",
        )
        log.info("[SNS] OTP sent to ****%s", phone[-4:])

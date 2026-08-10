from __future__ import annotations

from app.core.config import settings
from app.core.enums import TranscribeSpecialty
from app.services.fakes import FakeTranscribeClient


def _transcribe() -> FakeTranscribeClient:
    # The fake stub must never silently stand in outside local dev.
    if not settings.is_local:
        raise RuntimeError(
            "real Transcribe not wired — set ENVIRONMENT=local or implement"
        )
    return FakeTranscribeClient()


class TranscriptionService:
    @staticmethod
    async def start(
        *, message_id: str, s3_key: str, specialty: TranscribeSpecialty = TranscribeSpecialty.PRIMARYCARE
    ) -> None:
        await _transcribe().start_medical_job(
            message_id=message_id, s3_key=s3_key, specialty=specialty.value
        )

    @staticmethod
    async def fetch(*, message_id: str) -> str:
        return await _transcribe().fetch_transcript(message_id)

from __future__ import annotations

from app.core.enums import TranscribeSpecialty
from app.services.fakes import FakeTranscribeClient


def _transcribe() -> FakeTranscribeClient:
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

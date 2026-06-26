from __future__ import annotations

import uuid

from app.core.constants import PRESIGNED_URL_TTL_SECONDS
from app.services.s3_client import RealS3Client

_s3_instance = RealS3Client()


class FileService:
    @staticmethod
    def key_for_file(*, org_id: uuid.UUID, message_id: uuid.UUID, filename: str) -> str:
        return f"files/{org_id}/{message_id}/{filename}"

    @staticmethod
    def key_for_voice_note(*, org_id: uuid.UUID, message_id: uuid.UUID) -> str:
        return f"voice-notes/{org_id}/{message_id}.m4a"

    @staticmethod
    def key_for_avatar(*, user_id: uuid.UUID, filename: str) -> str:
        return f"avatars/{user_id}/{filename}"

    @staticmethod
    async def upload_bytes(*, key: str, data: bytes, content_type: str) -> str:
        await _s3_instance.upload_bytes(key=key, data=data, content_type=content_type)
        return key

    @staticmethod
    async def presigned_url(*, key: str, expires_in: int = PRESIGNED_URL_TTL_SECONDS) -> str:
        return await _s3_instance.presigned_url(key=key, expires_in=expires_in)

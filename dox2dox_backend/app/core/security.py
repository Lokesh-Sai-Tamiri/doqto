"""JWT + message encryption. Never inline these — always call through helpers."""

from __future__ import annotations

import base64
import os
import uuid
from datetime import datetime, timedelta, timezone

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from jose import JWTError, jwt

from app.core.config import settings
from app.core.constants import ACCESS_TOKEN_TTL_SECONDS, REFRESH_TOKEN_TTL_SECONDS
from app.core.enums import JwtTokenType

JWT_ALGORITHM = "HS256"


class TokenError(Exception):
    pass


def _now() -> datetime:
    return datetime.now(tz=timezone.utc)


def create_token(user_id: uuid.UUID | str, token_type: JwtTokenType, jti: str | None = None) -> tuple[str, str]:
    """Returns (token, jti)."""
    jti = jti or uuid.uuid4().hex
    ttl = ACCESS_TOKEN_TTL_SECONDS if token_type == JwtTokenType.ACCESS else REFRESH_TOKEN_TTL_SECONDS
    payload = {
        "sub": str(user_id),
        "jti": jti,
        "type": token_type.value,
        "iat": int(_now().timestamp()),
        "exp": int((_now() + timedelta(seconds=ttl)).timestamp()),
    }
    token = jwt.encode(payload, settings.JWT_SECRET, algorithm=JWT_ALGORITHM)
    return token, jti


def decode_token(token: str, expected_type: JwtTokenType) -> dict:
    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except JWTError as e:
        raise TokenError("invalid_token") from e
    if payload.get("type") != expected_type.value:
        raise TokenError("wrong_token_type")
    return payload


# ---------- Message encryption (AES-256-GCM) ----------


def _encryption_key() -> bytes:
    key = base64.b64decode(settings.MESSAGE_ENCRYPTION_KEY)
    if len(key) != 32:
        # In local dev, derive a deterministic 32-byte key from the provided value so the app boots.
        if settings.is_local:
            raw = settings.MESSAGE_ENCRYPTION_KEY.encode()
            return (raw * (32 // max(len(raw), 1) + 1))[:32]
        raise ValueError("MESSAGE_ENCRYPTION_KEY must decode to exactly 32 bytes")
    return key


def encrypt_message(plaintext: str) -> bytes:
    aesgcm = AESGCM(_encryption_key())
    nonce = os.urandom(12)
    ciphertext = aesgcm.encrypt(nonce, plaintext.encode(), None)
    return nonce + ciphertext


def decrypt_message(blob: bytes) -> str:
    aesgcm = AESGCM(_encryption_key())
    nonce, ciphertext = blob[:12], blob[12:]
    return aesgcm.decrypt(nonce, ciphertext, None).decode()

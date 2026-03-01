"""
AES-256-GCM field-level encryption for PHI (Protected Health Information).

Key generation (run once, add result to .env as MESSAGE_ENCRYPTION_KEY):
    python -c "import os,base64; print(base64.b64encode(os.urandom(32)).decode())"
"""

import binascii
import logging
import os
import base64
from typing import Optional

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

logger = logging.getLogger(__name__)

from config import settings


class EncryptionService:
    """Thin AES-256-GCM encrypt/decrypt wrapper for message content."""

    _instance: Optional[AESGCM] = None

    @classmethod
    def _get_cipher(cls) -> Optional[AESGCM]:
        if cls._instance is None:
            raw = settings.message_encryption_key
            if not raw:
                return None
            cls._instance = AESGCM(base64.b64decode(raw))  # must decode to exactly 32 bytes
        return cls._instance

    @classmethod
    def encrypt(cls, plaintext: str) -> Optional[str]:
        """Encrypt plaintext with AES-256-GCM. Returns base64(nonce + ciphertext)."""
        cipher = cls._get_cipher()
        if not cipher or not plaintext:
            return plaintext
        nonce = os.urandom(12)  # 96-bit GCM nonce
        ct = cipher.encrypt(nonce, plaintext.encode(), None)
        return base64.b64encode(nonce + ct).decode()

    @classmethod
    def decrypt(cls, ciphertext: str) -> Optional[str]:
        """Decrypt base64(nonce + ciphertext) produced by encrypt()."""
        cipher = cls._get_cipher()
        if not cipher or not ciphertext:
            return ciphertext
        try:
            raw = base64.b64decode(ciphertext)
            return cipher.decrypt(raw[:12], raw[12:], None).decode()
        except (InvalidTag, binascii.Error, ValueError):
            # Legacy message stored before encryption was enabled — return as-is.
            logger.warning("decrypt: InvalidTag or bad base64, returning raw value")
            return ciphertext

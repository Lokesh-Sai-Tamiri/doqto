"""Per-key fixed-window rate limiting on Redis.

ponytail: fixed window (INCR + EXPIRE) — sliding window/token bucket only if
burst shaping ever matters.
"""

from __future__ import annotations

import uuid

from fastapi import HTTPException, status

from app.core.constants import RATE_LIMIT_DEFAULT_PER_MINUTE
from app.core.redis_keys import rate_limit_key
from app.db.redis import get_redis


async def enforce_rate_limit(
    key_id: uuid.UUID | str,
    endpoint: str,
    limit: int = RATE_LIMIT_DEFAULT_PER_MINUTE,
    window_seconds: int = 60,
) -> None:
    """Raise 429 when `key_id` (user id, email, …) exceeds `limit` calls per
    `window_seconds` on `endpoint`."""
    redis = await get_redis()
    key = rate_limit_key(key_id, endpoint)
    count = await redis.incr(key)
    if count == 1:
        await redis.expire(key, window_seconds)
    if count > limit:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, detail="rate_limited")

"""Per-user fixed-window rate limiting on Redis.

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
    user_id: uuid.UUID, endpoint: str, limit: int = RATE_LIMIT_DEFAULT_PER_MINUTE
) -> None:
    """Raise 429 when the user exceeds `limit` calls/minute on `endpoint`."""
    redis = await get_redis()
    key = rate_limit_key(user_id, endpoint)
    count = await redis.incr(key)
    if count == 1:
        await redis.expire(key, 60)
    if count > limit:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, detail="rate_limited")

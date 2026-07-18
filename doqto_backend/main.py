from __future__ import annotations

import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import websocket as ws_router
from app.api.ws_manager import ws_manager
from app.api.v1 import admin, auth, conversations, messages, orgs, users
from app.core.config import settings
from app.core.constants import DISAPPEAR_PURGE_INTERVAL_SEC
from app.core.redis_keys import purge_lock_key
from app.core.routes import ApiPrefix
from app.db.postgres import SessionLocal
from app.db.redis import close_redis, get_redis
from app.services.message_service import MessageService

logger = logging.getLogger("doqto")


async def _purge_expired_loop() -> None:
    """Soft-delete disappearing messages past their expiry, forever."""
    while True:
        try:
            # Redis NX lock: with N replicas only one runs each purge tick.
            redis = await get_redis()
            got_lock = await redis.set(
                purge_lock_key(), "1", nx=True, ex=DISAPPEAR_PURGE_INTERVAL_SEC - 5
            )
            if got_lock:
                async with SessionLocal() as db:
                    purged = await MessageService.purge_expired(db)
                    await db.commit()
                    if purged:
                        logger.info("purged %d expired messages", purged)
        except Exception:
            logger.exception("purge_expired failed")
        await asyncio.sleep(DISAPPEAR_PURGE_INTERVAL_SEC)


@asynccontextmanager
async def lifespan(_: FastAPI):
    purge_task = asyncio.create_task(_purge_expired_loop())
    # Pumps Redis pub/sub → this instance's sockets (multi-worker fanout).
    subscriber_task = asyncio.create_task(ws_manager.run_subscriber())
    yield
    purge_task.cancel()
    subscriber_task.cancel()
    await close_redis()


app = FastAPI(title="Doqto API", version="1.0.0", lifespan=lifespan)

# Wildcard origins + credentials is never acceptable outside local dev.
if not settings.allowed_origins_list and settings.ENVIRONMENT != "local":
    raise RuntimeError("ALLOWED_ORIGINS must be set outside local environment")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list or ["*"],  # "*" only in local
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix=ApiPrefix.AUTH, tags=["auth"])
app.include_router(users.router, prefix=ApiPrefix.USERS, tags=["users"])
app.include_router(orgs.router, prefix=ApiPrefix.ORGS, tags=["orgs"])
app.include_router(conversations.router, prefix=ApiPrefix.CONVERSATIONS, tags=["conversations"])
app.include_router(messages.router, prefix=ApiPrefix.MESSAGES, tags=["messages"])
app.include_router(admin.router, prefix=ApiPrefix.ADMIN, tags=["admin"])
app.include_router(ws_router.router)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok", "env": settings.ENVIRONMENT}



from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import websocket as ws_router
from app.api.v1 import admin, auth, conversations, messages, orgs, users
from app.core.config import settings
from app.core.routes import ApiPrefix
from app.db.redis import close_redis


@asynccontextmanager
async def lifespan(_: FastAPI):
    yield
    await close_redis()


app = FastAPI(title="Dox2Dox API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list or ["*"],
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



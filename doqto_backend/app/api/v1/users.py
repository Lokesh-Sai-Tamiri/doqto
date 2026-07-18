from __future__ import annotations

import logging
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.constants import (
    AVATAR_ALLOWED_EXT,
    AVATAR_ALLOWED_MIME,
    AVATAR_MAX_BYTES,
)
from app.core.dependencies import get_current_user
from app.core.routes import ApiRoutes
from app.db.postgres import get_db
from app.models import User
from app.schemas.common import OkResponse
from app.schemas.push import PushTokenDeleteIn, PushTokenIn
from app.schemas.user import UserOut, UserPatch, build_user_out
from app.services.file_service import FileService
from app.services.push_service import PushService

router = APIRouter()


@router.get("/me", response_model=UserOut)
async def me(user: User = Depends(get_current_user)) -> UserOut:
    return await build_user_out(user)


@router.patch("/me", response_model=UserOut)
async def update_me(
    body: UserPatch,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> UserOut:
    data = body.model_dump(exclude_unset=True)
    for field in (
        "full_name",
        "email",
        "specialty",
        "bio",
        "city",
        "state",
        "years_of_experience",
        "skills",
    ):
        if field in data:
            setattr(user, field, data[field])
    await db.flush()
    await db.refresh(user)
    return await build_user_out(user)


@router.post("/me/avatar", response_model=UserOut)
async def upload_avatar(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> UserOut:
    if file.content_type not in AVATAR_ALLOWED_MIME:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="avatar_unsupported_type")
    data = await file.read()
    if len(data) > AVATAR_MAX_BYTES:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="avatar_too_large")
    if not data:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="avatar_empty")
    ext = AVATAR_ALLOWED_EXT[file.content_type]
    key = f"avatars/{user.id}/{uuid.uuid4()}.{ext}"
    await FileService.upload_bytes(key=key, data=data, content_type=file.content_type)
    user.avatar_url = key
    await db.flush()
    await db.refresh(user)
    return await build_user_out(user)


@router.post(ApiRoutes.USERS_PUSH_TOKENS, response_model=OkResponse)
async def register_push_token(
    body: PushTokenIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> OkResponse:
    await PushService.register_token(
        user_id=user.id, token=body.token, platform=body.platform.value, db=db
    )
    return OkResponse()


@router.delete(ApiRoutes.USERS_PUSH_TOKENS, response_model=OkResponse)
async def unregister_push_token(
    body: PushTokenDeleteIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> OkResponse:
    await PushService.unregister_token(user_id=user.id, token=body.token, db=db)
    return OkResponse()


@router.delete("/me/avatar", response_model=UserOut)
async def delete_avatar(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> UserOut:
    # Disposal: remove the S3 object too (avatar_url stores the S3 key).
    # Best-effort — the DB pointer is cleared regardless.
    if user.avatar_url:
        try:
            await FileService.delete_object(key=user.avatar_url)
        except Exception:
            logging.getLogger("doqto.users").warning(
                "avatar S3 delete failed for key %s", user.avatar_url
            )
    user.avatar_url = None
    await db.flush()
    await db.refresh(user)
    return await build_user_out(user)

"""People search (M2) — cross-org professional directory surface.

Distinct from /orgs/{id}/members (which stays minimum-necessary org-only).
Cards NEVER carry phone/email/npi_number.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.constants import (
    PEOPLE_SEARCH_MAX_LIMIT,
    PEOPLE_SEARCH_PAGE_SIZE,
    PEOPLE_SEARCH_PER_MINUTE,
)
from app.core.dependencies import get_current_user
from app.core.rate_limit import enforce_rate_limit
from app.core.routes import ApiRoutes
from app.db.postgres import get_db
from app.models import User
from app.schemas.people import PeopleSearchPage
from app.services.people_search_service import PeopleSearchFilters, people_search

router = APIRouter()


@router.get(ApiRoutes.PEOPLE_SEARCH, response_model=PeopleSearchPage)
async def search_people(
    q: str | None = Query(default=None, max_length=100),
    specialty: str | None = Query(default=None, max_length=100),
    state: str | None = Query(default=None, max_length=2),
    degree: int | None = Query(default=None, ge=1, le=2),
    cursor: str | None = Query(default=None),
    limit: int = Query(default=PEOPLE_SEARCH_PAGE_SIZE, ge=1, le=PEOPLE_SEARCH_MAX_LIMIT),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PeopleSearchPage:
    await enforce_rate_limit(user.id, "people_search", PEOPLE_SEARCH_PER_MINUTE, 60)
    cards, next_cursor = await people_search.search(
        viewer_id=user.id,
        query=q,
        filters=PeopleSearchFilters(specialty=specialty, state=state, degree=degree),
        cursor=cursor,
        limit=limit,
        db=db,
    )
    return PeopleSearchPage(data=cards, next_cursor=next_cursor)

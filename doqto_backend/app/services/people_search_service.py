"""People search (M2).

`PeopleSearchProvider` is a deliberately narrow interface so an OpenSearch /
materialised-view implementation can slot in at M7 without touching callers.
`PgTrgmPeopleSearch` is the Postgres implementation used through M2–M6.

Security boundary: relationship/visibility rules are enforced at the SQL level
so an excluded user can never leak into a page (blocked pairs, discoverability,
org directory visibility). Degree membership comes from RelationshipService —
this module never reimplements the graph.

HIPAA: PersonCardOut carries NO phone / email / npi_number. The SELECT pulls
only directory columns; the schema has no PHI fields to populate.

trgm-vs-ILIKE: fuzzy ranking uses similarity() only when the pg_trgm extension
is present (detected once per call via pg_extension). Otherwise ranking falls
back to a deterministic ILIKE case expression. Filtering is ALWAYS ILIKE, so
search is correct with or without the extension — the test harness builds
schema via Base.metadata.create_all and has no pg_trgm, and still passes.
"""
from __future__ import annotations

import uuid
from abc import ABC, abstractmethod
from dataclasses import dataclass

from sqlalchemy import case, exists, func, literal, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.constants import (
    SEARCH_DEGREE_BOOST_FIRST,
    SEARCH_DEGREE_BOOST_SECOND,
    SEARCH_SAME_ORG_BOOST,
)
from app.core.enums import DirectoryVisibility, Discoverability, UserRole
from app.models import Connection, Organization, OrgMember, User, UserPrivacySettings
from app.schemas.people import PersonCardOut, location_label
from app.services.file_service import FileService
from app.services.relationship_service import RelationshipService


@dataclass(frozen=True)
class PeopleSearchFilters:
    specialty: str | None = None
    state: str | None = None
    degree: int | None = None  # 1 (first-degree) | 2 (second-degree) | None


class PeopleSearchProvider(ABC):
    @abstractmethod
    async def search(
        self,
        *,
        viewer_id: uuid.UUID,
        query: str | None,
        filters: PeopleSearchFilters,
        cursor: str | None,
        limit: int,
        db: AsyncSession,
    ) -> tuple[list[PersonCardOut], str | None]:
        """Return (cards, next_cursor)."""

    async def typeahead(
        self, *, viewer_id: uuid.UUID, query: str, limit: int, db: AsyncSession
    ) -> list[PersonCardOut]:
        cards, _ = await self.search(
            viewer_id=viewer_id,
            query=query,
            filters=PeopleSearchFilters(),
            cursor=None,
            limit=limit,
            db=db,
        )
        return cards


class PgTrgmPeopleSearch(PeopleSearchProvider):
    async def search(
        self,
        *,
        viewer_id: uuid.UUID,
        query: str | None,
        filters: PeopleSearchFilters,
        cursor: str | None,
        limit: int,
        db: AsyncSession,
    ) -> tuple[list[PersonCardOut], str | None]:
        q = (query or "").strip() or None

        viewer_fd = await RelationshipService.first_degree_ids(viewer_id, db)
        viewer_sd = await RelationshipService.second_degree_ids(viewer_id, db)
        blocked = await RelationshipService._blocked_ids(viewer_id, db)
        viewer_orgs = await RelationshipService._org_ids(viewer_id, db)

        has_trgm = bool(
            await db.scalar(text("SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm'"))
        )

        # --- visibility subqueries (correlated to the outer users row) --- #
        shared_org = exists(
            select(OrgMember.id).where(
                OrgMember.user_id == User.id,
                OrgMember.org_id.in_(viewer_orgs) if viewer_orgs else literal(False),
            )
        )
        public_org = exists(
            select(OrgMember.id)
            .join(Organization, Organization.id == OrgMember.org_id)
            .where(
                OrgMember.user_id == User.id,
                Organization.directory_visibility != DirectoryVisibility.ORG_ONLY.value,
            )
        )
        any_org = exists(select(OrgMember.id).where(OrgMember.user_id == User.id))

        disc = func.coalesce(
            UserPrivacySettings.discoverability, Discoverability.EVERYONE.value
        )

        stmt = (
            select(User)
            .outerjoin(UserPrivacySettings, UserPrivacySettings.user_id == User.id)
            .where(User.id != viewer_id)
            .where(User.role == UserRole.DOCTOR.value)
            .where(User.deleted_at.is_(None))
        )
        if blocked:
            stmt = stmt.where(User.id.notin_(blocked))

        # Text match (always ILIKE — correct regardless of pg_trgm).
        if q:
            pat = f"%{q}%"
            stmt = stmt.where(
                or_(
                    User.full_name.ilike(pat),
                    User.headline.ilike(pat),
                    User.specialty.ilike(pat),
                )
            )

        # Explicit filters.
        if filters.specialty:
            stmt = stmt.where(User.specialty.ilike(f"%{filters.specialty}%"))
        if filters.state:
            stmt = stmt.where(User.state.ilike(filters.state))
        if filters.degree == 1:
            stmt = stmt.where(User.id.in_(viewer_fd) if viewer_fd else literal(False))
        elif filters.degree == 2:
            stmt = stmt.where(User.id.in_(viewer_sd) if viewer_sd else literal(False))

        # Privacy: exclude discoverability='nobody'; 'connections' needs 1st-degree.
        stmt = stmt.where(disc != Discoverability.NOBODY.value)
        stmt = stmt.where(
            or_(
                disc != Discoverability.CONNECTIONS.value,
                User.id.in_(viewer_fd) if viewer_fd else literal(False),
            )
        )

        # Org directory visibility: hide a user whose orgs are ALL 'org_only'
        # unless the viewer shares an org. Users with no org stay visible.
        stmt = stmt.where(or_(shared_org, public_org, ~any_org))

        # --- deterministic ranking (no ML) --- #
        if q and has_trgm:
            text_rank = func.greatest(
                func.similarity(User.full_name, q),
                func.similarity(func.coalesce(User.headline, ""), q),
                func.similarity(func.coalesce(User.specialty, ""), q),
            )
        elif q:
            text_rank = case(
                (User.full_name.ilike(q), literal(1.0)),
                (User.full_name.ilike(f"{q}%"), literal(0.8)),
                (User.full_name.ilike(f"%{q}%"), literal(0.5)),
                else_=literal(0.2),
            )
        else:
            text_rank = literal(0.0)

        degree_boost = case(
            (
                User.id.in_(viewer_fd) if viewer_fd else literal(False),
                literal(SEARCH_DEGREE_BOOST_FIRST),
            ),
            (
                User.id.in_(viewer_sd) if viewer_sd else literal(False),
                literal(SEARCH_DEGREE_BOOST_SECOND),
            ),
            else_=literal(0.0),
        )
        org_boost = case((shared_org, literal(SEARCH_SAME_ORG_BOOST)), else_=literal(0.0))
        score = text_rank + degree_boost + org_boost

        offset = _parse_offset(cursor)
        stmt = stmt.order_by(score.desc(), User.full_name.asc(), User.id.asc())
        stmt = stmt.offset(offset).limit(limit + 1)

        rows = list((await db.scalars(stmt)).all())
        next_cursor: str | None = None
        if len(rows) > limit:
            rows = rows[:limit]
            next_cursor = str(offset + limit)

        mutual_counts = await self._mutual_counts([u.id for u in rows], viewer_fd, db)

        cards: list[PersonCardOut] = []
        for u in rows:
            cards.append(
                PersonCardOut(
                    id=u.id,
                    full_name=u.full_name,
                    headline=u.headline,
                    specialty=u.specialty,
                    location_label=location_label(u.city, u.state),
                    avatar_color=u.avatar_color,
                    avatar_url=u.avatar_url,
                    avatar_presigned_url=(
                        await FileService.presigned_url(key=u.avatar_url)
                        if u.avatar_url
                        else None
                    ),
                    degree=_degree_label(u.id, viewer_fd, viewer_sd),
                    mutual_count=mutual_counts.get(u.id, 0),
                )
            )
        return cards, next_cursor

    @staticmethod
    async def _mutual_counts(
        target_ids: list[uuid.UUID], viewer_fd: set[uuid.UUID], db: AsyncSession
    ) -> dict[uuid.UUID, int]:
        if not target_ids or not viewer_fd:
            return {}
        rows = await db.execute(
            select(Connection.user_id, func.count())
            .where(
                Connection.user_id.in_(target_ids),
                Connection.connected_user_id.in_(viewer_fd),
            )
            .group_by(Connection.user_id)
        )
        return {uid: cnt for uid, cnt in rows.all()}


def _parse_offset(cursor: str | None) -> int:
    if not cursor:
        return 0
    try:
        val = int(cursor)
    except (TypeError, ValueError):
        return 0
    return max(0, val)


def _degree_label(
    uid: uuid.UUID, viewer_fd: set[uuid.UUID], viewer_sd: set[uuid.UUID]
) -> str:
    if uid in viewer_fd:
        return "1st"
    if uid in viewer_sd:
        return "2nd"
    return "3rd"


# Module-level provider singleton (swap point for M7).
people_search: PeopleSearchProvider = PgTrgmPeopleSearch()

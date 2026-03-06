"""API v1 routes module."""

from fastapi import APIRouter

from api.v1 import profiles, messaging, connections, organizations, billing

router = APIRouter(prefix="/api/v1")

# Include all route modules
router.include_router(profiles.router, tags=["Profiles"])
router.include_router(messaging.router, tags=["Messaging"])
router.include_router(connections.router, tags=["Connections"])
router.include_router(organizations.router, tags=["Organizations"])
router.include_router(billing.router, tags=["Billing"])

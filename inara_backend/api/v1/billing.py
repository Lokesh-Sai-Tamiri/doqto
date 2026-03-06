"""
Billing API endpoints — Stripe Checkout, Customer Portal, and webhook.
"""

from typing import List

from fastapi import APIRouter, Depends, HTTPException, Request, status

from middleware.auth import get_current_user, AuthUser
from api.models.billing import (
    CheckoutRequest,
    CheckoutResponse,
    PlanInfo,
    PortalRequest,
    PortalResponse,
    SubscriptionModel,
)
from db.collections import Collections
from services.billing_service import BillingService
from services.organization_service import OrganizationService

router = APIRouter(prefix="/billing")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def _require_org_owner(org_id: str, user_id: str) -> None:
    """Raise 403 unless the caller is an owner or admin of the org."""
    doc = await Collections.organization_memberships().find_one(
        {
            "organization_id": org_id,
            "user_id": user_id,
            "role": {"$in": ["owner", "admin"]},
        }
    )
    if not doc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only org owners and admins can manage billing",
        )


async def _require_org_member(org_id: str, user_id: str) -> None:
    """Raise 403 unless the caller is a member of the org."""
    doc = await Collections.organization_memberships().find_one(
        {"organization_id": org_id, "user_id": user_id}
    )
    if not doc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this organization",
        )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get("/plans", response_model=List[PlanInfo])
async def list_plans():
    """Return all available subscription plans with pricing."""
    return BillingService.get_plans()


@router.get("/subscription", response_model=SubscriptionModel)
async def get_subscription(
    org_id: str,
    user: AuthUser = Depends(get_current_user),
):
    """Get the current subscription for an organization."""
    await _require_org_member(org_id, user.user_id)

    sub = await BillingService.get_subscription(org_id)
    if not sub:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No subscription found for this organization",
        )
    return sub


@router.post("/checkout", response_model=CheckoutResponse)
async def create_checkout(
    data: CheckoutRequest,
    user: AuthUser = Depends(get_current_user),
):
    """Create a Stripe Checkout Session (org owner/admin only)."""
    await _require_org_owner(data.org_id, user.user_id)

    # Fetch org details for Stripe customer creation
    org = await OrganizationService.get_organization(data.org_id, user.user_id)
    if not org:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Organization not found",
        )

    try:
        url = await BillingService.create_checkout_session(
            org_id=data.org_id,
            org_name=org.name,
            owner_email=user.email,
            plan=data.plan,
            seats=data.seats,
            success_url=data.success_url,
            cancel_url=data.cancel_url,
        )
        return CheckoutResponse(checkout_url=url)
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create checkout session: {exc}",
        )


@router.post("/portal", response_model=PortalResponse)
async def create_portal(
    data: PortalRequest,
    user: AuthUser = Depends(get_current_user),
):
    """Create a Stripe Customer Portal session (org owner/admin only)."""
    await _require_org_owner(data.org_id, user.user_id)

    try:
        url = await BillingService.create_portal_session(
            org_id=data.org_id,
            return_url=data.return_url,
        )
        return PortalResponse(portal_url=url)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        )
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create portal session: {exc}",
        )


@router.post("/webhook", status_code=status.HTTP_200_OK)
async def stripe_webhook(request: Request):
    """Receive and process Stripe webhook events."""
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature", "")

    try:
        await BillingService.handle_webhook(payload, sig_header)
    except ValueError as exc:
        # Signature mismatch or missing org_id
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        )
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        )

    return {"received": True}

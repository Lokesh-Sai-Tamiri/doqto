"""
Billing service — Stripe Checkout, Customer Portal, and webhook handling.
Follows the static-method pattern used by ProfileService / MessagingService.
"""

from datetime import datetime, timezone
from typing import Optional

import stripe
from bson import ObjectId
from loguru import logger

from config import settings
from db.collections import Collections
from api.models.billing import (
    PlanInfo,
    SubscriptionPlan,
    SubscriptionStatus,
    SubscriptionModel,
)


# ---------------------------------------------------------------------------
# Plan catalogue (no Stripe objects needed — we use price_data in checkout)
# ---------------------------------------------------------------------------

_PLANS: list[PlanInfo] = [
    PlanInfo(
        id=SubscriptionPlan.clinic,
        name="Clinic",
        min_seats=10,
        max_seats=25,
        price_per_seat_year=120_00,  # $120.00 in cents
        features=[
            "Up to 25 seats",
            "Secure messaging",
            "Voice messages",
            "Organization directory",
            "14-day free trial",
        ],
    ),
    PlanInfo(
        id=SubscriptionPlan.practice,
        name="Practice",
        min_seats=26,
        max_seats=100,
        price_per_seat_year=96_00,  # $96.00
        features=[
            "26–100 seats",
            "All Clinic features",
            "Department management",
            "Priority support",
            "14-day free trial",
        ],
    ),
    PlanInfo(
        id=SubscriptionPlan.hospital,
        name="Hospital",
        min_seats=101,
        max_seats=500,
        price_per_seat_year=72_00,  # $72.00
        features=[
            "101–500 seats",
            "All Practice features",
            "Audit logs",
            "SSO integration",
            "14-day free trial",
        ],
    ),
    PlanInfo(
        id=SubscriptionPlan.network,
        name="Network",
        min_seats=501,
        max_seats=None,
        price_per_seat_year=60_00,  # $60.00
        features=[
            "500+ seats",
            "All Hospital features",
            "Dedicated support",
            "Custom integrations",
            "14-day free trial",
        ],
    ),
]

_PLAN_BY_ID: dict[str, PlanInfo] = {p.id.value: p for p in _PLANS}


def _stripe_client() -> stripe.StripeClient:
    """Return a configured Stripe client."""
    if not settings.stripe_secret_key:
        raise RuntimeError("STRIPE_SECRET_KEY is not configured")
    return stripe.StripeClient(settings.stripe_secret_key)


class BillingService:
    """Service for all subscription and payment operations."""

    # ------------------------------------------------------------------
    # Plan catalogue
    # ------------------------------------------------------------------

    @staticmethod
    def get_plans() -> list[PlanInfo]:
        return _PLANS

    # ------------------------------------------------------------------
    # Stripe customer
    # ------------------------------------------------------------------

    @staticmethod
    async def get_or_create_customer(
        org_id: str, org_name: str, owner_email: Optional[str]
    ) -> str:
        """Return existing Stripe customer ID or create a new one."""
        doc = await Collections.org_subscriptions().find_one({"org_id": org_id})
        if doc and doc.get("stripe_customer_id"):
            return doc["stripe_customer_id"]

        client = _stripe_client()
        customer = client.customers.create(
            params={
                "name": org_name,
                "email": owner_email,
                "metadata": {"org_id": org_id},
            }
        )
        return customer.id

    # ------------------------------------------------------------------
    # Checkout session
    # ------------------------------------------------------------------

    @staticmethod
    async def create_checkout_session(
        org_id: str,
        org_name: str,
        owner_email: Optional[str],
        plan: SubscriptionPlan,
        seats: int,
        success_url: str,
        cancel_url: str,
    ) -> str:
        """Create a Stripe Checkout Session and return the URL."""
        plan_info = _PLAN_BY_ID[plan.value]
        customer_id = await BillingService.get_or_create_customer(
            org_id, org_name, owner_email
        )

        client = _stripe_client()
        session = client.checkout.sessions.create(
            params={
                "customer": customer_id,
                "mode": "subscription",
                "payment_method_types": ["card"],
                "line_items": [
                    {
                        "price_data": {
                            "currency": "usd",
                            "recurring": {"interval": "year"},
                            "unit_amount": plan_info.price_per_seat_year,
                            "product_data": {
                                "name": f"HymnChat {plan_info.name} Plan",
                                "description": f"Annual subscription — {seats} seat(s)",
                            },
                        },
                        "quantity": seats,
                    }
                ],
                "subscription_data": {
                    "trial_period_days": 14,
                    "metadata": {
                        "org_id": org_id,
                        "plan": plan.value,
                        "seats": str(seats),
                    },
                },
                "success_url": success_url,
                "cancel_url": cancel_url,
            }
        )
        return session.url

    # ------------------------------------------------------------------
    # Customer Portal
    # ------------------------------------------------------------------

    @staticmethod
    async def create_portal_session(org_id: str, return_url: str) -> str:
        """Create a Stripe Customer Portal session and return the URL."""
        doc = await Collections.org_subscriptions().find_one({"org_id": org_id})
        if not doc or not doc.get("stripe_customer_id"):
            raise ValueError("No Stripe customer found for this organization")

        client = _stripe_client()
        session = client.billing_portal.sessions.create(
            params={
                "customer": doc["stripe_customer_id"],
                "return_url": return_url,
            }
        )
        return session.url

    # ------------------------------------------------------------------
    # Read subscription from MongoDB
    # ------------------------------------------------------------------

    @staticmethod
    async def get_subscription(org_id: str) -> Optional[SubscriptionModel]:
        doc = await Collections.org_subscriptions().find_one({"org_id": org_id})
        if doc:
            return BillingService._doc_to_model(doc)
        return None

    # ------------------------------------------------------------------
    # Webhook handler
    # ------------------------------------------------------------------

    @staticmethod
    async def handle_webhook(payload: bytes, sig_header: str) -> None:
        """Verify Stripe signature and dispatch to internal handlers."""
        if not settings.stripe_webhook_secret:
            raise RuntimeError("STRIPE_WEBHOOK_SECRET is not configured")

        try:
            event = stripe.Webhook.construct_event(
                payload, sig_header, settings.stripe_webhook_secret
            )
        except stripe.error.SignatureVerificationError as e:
            raise ValueError(f"Invalid Stripe signature: {e}") from e

        event_id = event["id"]

        # Idempotency check
        existing = await Collections.stripe_events().find_one(
            {"stripe_event_id": event_id}
        )
        if existing:
            logger.info(f"Stripe event {event_id} already processed — skipping")
            return

        # Dispatch
        event_type = event["type"]
        try:
            if event_type == "checkout.session.completed":
                await BillingService._handle_checkout_completed(event["data"]["object"])
            elif event_type in ("customer.subscription.updated", "invoice.payment_succeeded"):
                await BillingService._handle_subscription_updated(event["data"]["object"])
            elif event_type in ("customer.subscription.deleted", "invoice.payment_failed"):
                await BillingService._handle_subscription_deleted(event["data"]["object"])
            else:
                logger.debug(f"Unhandled Stripe event type: {event_type}")
        except Exception as exc:
            logger.error(f"Error processing Stripe event {event_id}: {exc}")
            raise

        # Mark event as processed
        await Collections.stripe_events().insert_one(
            {
                "stripe_event_id": event_id,
                "event_type": event_type,
                "processed_at": datetime.now(timezone.utc),
            }
        )

    # ------------------------------------------------------------------
    # Internal handlers
    # ------------------------------------------------------------------

    @staticmethod
    async def _handle_checkout_completed(session: dict) -> None:
        """Persist subscription record after a successful Checkout."""
        meta = session.get("subscription_data", {}).get("metadata") or {}
        # Metadata may also live directly on the session for some Stripe versions
        if not meta.get("org_id"):
            meta = session.get("metadata") or {}

        org_id = meta.get("org_id")
        if not org_id:
            logger.warning("checkout.session.completed missing org_id in metadata")
            return

        plan_str = meta.get("plan", SubscriptionPlan.clinic.value)
        seats = int(meta.get("seats", 10))
        stripe_subscription_id = session.get("subscription")
        stripe_customer_id = session.get("customer")

        now = datetime.now(timezone.utc)
        await Collections.org_subscriptions().update_one(
            {"org_id": org_id},
            {
                "$set": {
                    "org_id": org_id,
                    "plan": plan_str,
                    "seats": seats,
                    "status": SubscriptionStatus.trialing.value,
                    "stripe_customer_id": stripe_customer_id,
                    "stripe_subscription_id": stripe_subscription_id,
                    "cancel_at_period_end": False,
                    "updated_at": now,
                },
                "$setOnInsert": {"created_at": now},
            },
            upsert=True,
        )
        logger.info(f"Subscription created for org {org_id}")

    @staticmethod
    async def _handle_subscription_updated(stripe_sub: dict) -> None:
        """Sync Stripe subscription status/period dates to MongoDB."""
        subscription_id = stripe_sub.get("id")
        if not subscription_id:
            return

        status_map = {
            "trialing": SubscriptionStatus.trialing.value,
            "active": SubscriptionStatus.active.value,
            "past_due": SubscriptionStatus.past_due.value,
            "canceled": SubscriptionStatus.canceled.value,
            "incomplete": SubscriptionStatus.incomplete.value,
            "incomplete_expired": SubscriptionStatus.canceled.value,
        }
        raw_status = stripe_sub.get("status", "incomplete")
        status = status_map.get(raw_status, SubscriptionStatus.incomplete.value)

        period_start = stripe_sub.get("current_period_start")
        period_end = stripe_sub.get("current_period_end")
        trial_end = stripe_sub.get("trial_end")
        cancel_at_period_end = stripe_sub.get("cancel_at_period_end", False)

        meta = stripe_sub.get("metadata") or {}
        plan_str = meta.get("plan")
        seats_str = meta.get("seats")

        update: dict = {
            "status": status,
            "stripe_subscription_id": subscription_id,
            "cancel_at_period_end": cancel_at_period_end,
            "updated_at": datetime.now(timezone.utc),
        }
        if period_start:
            update["current_period_start"] = datetime.fromtimestamp(
                period_start, tz=timezone.utc
            )
        if period_end:
            update["current_period_end"] = datetime.fromtimestamp(
                period_end, tz=timezone.utc
            )
        if trial_end:
            update["trial_end"] = datetime.fromtimestamp(trial_end, tz=timezone.utc)
        if plan_str:
            update["plan"] = plan_str
        if seats_str:
            update["seats"] = int(seats_str)

        result = await Collections.org_subscriptions().update_one(
            {"stripe_subscription_id": subscription_id},
            {"$set": update},
        )
        if result.matched_count == 0:
            logger.warning(
                f"No org_subscription found for stripe_subscription_id={subscription_id}"
            )

    @staticmethod
    async def _handle_subscription_deleted(stripe_sub: dict) -> None:
        """Mark subscription as canceled in MongoDB."""
        subscription_id = stripe_sub.get("id")
        if not subscription_id:
            return

        await Collections.org_subscriptions().update_one(
            {"stripe_subscription_id": subscription_id},
            {
                "$set": {
                    "status": SubscriptionStatus.canceled.value,
                    "updated_at": datetime.now(timezone.utc),
                }
            },
        )

    # ------------------------------------------------------------------
    # Helper
    # ------------------------------------------------------------------

    @staticmethod
    def _doc_to_model(doc: dict) -> SubscriptionModel:
        return SubscriptionModel(
            id=str(doc["_id"]),
            org_id=doc["org_id"],
            plan=SubscriptionPlan(doc.get("plan", SubscriptionPlan.clinic.value)),
            status=SubscriptionStatus(
                doc.get("status", SubscriptionStatus.incomplete.value)
            ),
            seats=doc.get("seats", 0),
            stripe_customer_id=doc.get("stripe_customer_id", ""),
            stripe_subscription_id=doc.get("stripe_subscription_id"),
            current_period_start=doc.get("current_period_start"),
            current_period_end=doc.get("current_period_end"),
            trial_end=doc.get("trial_end"),
            cancel_at_period_end=doc.get("cancel_at_period_end", False),
        )

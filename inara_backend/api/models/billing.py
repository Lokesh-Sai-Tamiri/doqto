"""
Pydantic models for the billing / subscription domain.
"""

from datetime import datetime
from enum import Enum
from typing import List, Optional

from pydantic import BaseModel


class SubscriptionPlan(str, Enum):
    clinic = "clinic"
    practice = "practice"
    hospital = "hospital"
    network = "network"


class SubscriptionStatus(str, Enum):
    trialing = "trialing"
    active = "active"
    past_due = "past_due"
    canceled = "canceled"
    incomplete = "incomplete"


class CheckoutRequest(BaseModel):
    org_id: str
    plan: SubscriptionPlan
    seats: int
    success_url: str
    cancel_url: str


class PortalRequest(BaseModel):
    org_id: str
    return_url: str


class SubscriptionModel(BaseModel):
    id: str
    org_id: str
    plan: SubscriptionPlan
    status: SubscriptionStatus
    seats: int
    stripe_customer_id: str
    stripe_subscription_id: Optional[str] = None
    current_period_start: Optional[datetime] = None
    current_period_end: Optional[datetime] = None
    trial_end: Optional[datetime] = None
    cancel_at_period_end: bool = False


class CheckoutResponse(BaseModel):
    checkout_url: str


class PortalResponse(BaseModel):
    portal_url: str


class PlanInfo(BaseModel):
    id: SubscriptionPlan
    name: str
    min_seats: int
    max_seats: Optional[int]  # None means unlimited
    price_per_seat_year: int  # USD cents
    features: List[str]

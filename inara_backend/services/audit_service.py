import logging
from datetime import datetime, timezone
import json
from typing import Optional, Dict, Any
from pydantic import BaseModel, Field
import sys

from db.mongodb import get_db

logger = logging.getLogger(__name__)
# Configure logger to output to stdout as required commonly by log aggregators
handler = logging.StreamHandler(sys.stdout)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.INFO)


class AuditEvent(BaseModel):
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    event_type: str
    user_id: Optional[str] = None
    target_id: Optional[str] = None
    resource: Optional[str] = None
    action: str
    status: str = "SUCCESS"
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)


class AuditService:
    """
    Centralized auditing service to ensure HIPAA compliance.
    HIPAA requires recording access and modifications to PHI.
    """

    COLLECTION_NAME = "audit_logs"

    @classmethod
    async def log_event(
        cls,
        event_type: str,
        action: str,
        user_id: Optional[str] = None,
        resource: Optional[str] = None,
        target_id: Optional[str] = None,
        status: str = "SUCCESS",
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> bool:
        """
        Log a security/audit event.

        Args:
            event_type: Category of event (PHI_ACCESS, AUTH, etc.)
            action: Specific action taken
            user_id: ID of the user performing the action
            resource: Resource type being accessed
            target_id: ID of the target resource
            status: SUCCESS or FAILURE
            ip_address: Client IP address
            user_agent: Client software identifier
            metadata: Any extra contextual info (NO PHI should be in here)
        """

        event = AuditEvent(
            timestamp=datetime.now(timezone.utc),
            event_type=event_type,
            user_id=user_id,
            resource=resource,
            action=action,
            status=status,
            target_id=target_id,
            ip_address=ip_address,
            user_agent=user_agent,
            metadata=metadata or {},
        )

        log_data = event.model_dump()

        # 1. Log to standard output / log aggregator (e.g. Datadog/CloudWatch)
        # Convert timestamp to ISO format string for JSON logging
        log_data_str = log_data.copy()
        log_data_str['timestamp'] = log_data_str['timestamp'].isoformat()
        logger.info(json.dumps(log_data_str))

        try:
            db = get_db()
            if db is not None:
                # 2. Persist to MongoDB for long-term retention (HIPAA: typically 6 years)
                await db[cls.COLLECTION_NAME].insert_one(log_data)
                return True
        except Exception as e:
            # If DB fails, at least we have the stdout log
            logging.error(f"Failed to write audit log to database: {e}")

        return False

    @classmethod
    async def log_phi_access(cls, user_id: str, resource_type: str, target_id: str, action: str = "read", **kwargs):
        """Helper specifically for logging access to PHI (Messages, Audio, Profiles)"""
        return await cls.log_event(
            event_type="PHI_ACCESS",
            user_id=user_id,
            resource=resource_type,
            action=action,
            target_id=target_id,
            **kwargs
        )

    @classmethod
    async def log_auth(cls, user_id: str, action: str, status: str = "SUCCESS", **kwargs):
        """Helper specifically for authentication events (login, logout, failed attempt)"""
        return await cls.log_event(
            event_type="AUTH",
            user_id=user_id,
            resource="session",
            action=action,
            status=status,
            **kwargs
        )

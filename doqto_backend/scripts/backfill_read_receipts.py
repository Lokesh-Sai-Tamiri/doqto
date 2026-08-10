"""One-shot: mark every existing message as read by all its non-sender members.

Makes historical messages render with the double-check (read) tick by default.
Safe to re-run — skips messages that already have a read receipt for that user.

    cd doqto_backend && source venv/bin/activate
    python -m scripts.backfill_read_receipts
"""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone

from sqlalchemy import select

from app.db.postgres import SessionLocal
from app.models import ConversationMember, Message, MessageReceipt


async def main() -> None:
    now = datetime.now(tz=timezone.utc)
    created = 0
    async with SessionLocal() as db:
        messages = (await db.execute(select(Message).where(Message.is_deleted.is_(False)))).scalars().all()
        for msg in messages:
            members = (
                await db.execute(
                    select(ConversationMember.user_id).where(
                        ConversationMember.conversation_id == msg.conversation_id,
                        ConversationMember.user_id != msg.sender_id,
                    )
                )
            ).scalars().all()
            for uid in members:
                existing = await db.scalar(
                    select(MessageReceipt).where(
                        MessageReceipt.message_id == msg.id,
                        MessageReceipt.user_id == uid,
                    )
                )
                if existing is None:
                    db.add(MessageReceipt(message_id=msg.id, user_id=uid, delivered_at=now, read_at=now))
                    created += 1
                elif existing.read_at is None:
                    existing.read_at = now
                    created += 1
        await db.commit()
    print(f"backfill done — {created} read receipts written across {len(messages)} messages")


if __name__ == "__main__":
    asyncio.run(main())

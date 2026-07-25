"""One-shot: seed conversation_members.last_read_seq / last_delivered_seq for
GROUP conversations from existing MessageReceipt rows (A3 hybrid receipts).

After M3, group conversations stop writing per-message MessageReceipt rows and
read O(1) seq cursors instead. This backfill translates the historical receipts
into those cursors so pre-M3 group threads keep correct unread / read-by ticks.

Idempotent — recomputes cursors from receipts each run; never lowers a cursor.
DIRECT conversations are untouched (they keep per-message receipts).

    cd doqto_backend && source venv/bin/activate
    python -m scripts.backfill_last_read_seq
"""

from __future__ import annotations

import asyncio

from sqlalchemy import func, select

from app.core.enums import ConversationType
from app.db.postgres import SessionLocal
from app.models import (
    Conversation,
    ConversationMember,
    Message,
    MessageReceipt,
)


async def main() -> None:
    updated = 0
    async with SessionLocal() as db:
        group_ids = (
            await db.execute(
                select(Conversation.id).where(
                    Conversation.type == ConversationType.GROUP
                )
            )
        ).scalars().all()

        for conv_id in group_ids:
            members = (
                await db.execute(
                    select(ConversationMember).where(
                        ConversationMember.conversation_id == conv_id
                    )
                )
            ).scalars().all()

            for member in members:
                # Highest seq this member has a read / delivered receipt for.
                read_seq = await db.scalar(
                    select(func.max(Message.seq))
                    .join(MessageReceipt, MessageReceipt.message_id == Message.id)
                    .where(
                        Message.conversation_id == conv_id,
                        MessageReceipt.user_id == member.user_id,
                        MessageReceipt.read_at.is_not(None),
                    )
                ) or 0
                delivered_seq = await db.scalar(
                    select(func.max(Message.seq))
                    .join(MessageReceipt, MessageReceipt.message_id == Message.id)
                    .where(
                        Message.conversation_id == conv_id,
                        MessageReceipt.user_id == member.user_id,
                        MessageReceipt.delivered_at.is_not(None),
                    )
                ) or 0
                # Delivered is implied by read.
                delivered_seq = max(delivered_seq, read_seq)

                new_read = max(member.last_read_seq, read_seq)
                new_delivered = max(member.last_delivered_seq, delivered_seq)
                if (
                    new_read != member.last_read_seq
                    or new_delivered != member.last_delivered_seq
                ):
                    member.last_read_seq = new_read
                    member.last_delivered_seq = new_delivered
                    updated += 1

        await db.commit()
    print(
        f"backfill done — {updated} group member cursors seeded "
        f"across {len(group_ids)} group conversations"
    )


if __name__ == "__main__":
    asyncio.run(main())

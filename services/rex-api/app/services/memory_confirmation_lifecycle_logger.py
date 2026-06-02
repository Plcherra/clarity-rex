import json
import logging
from typing import Optional

from app.services.memory_intent_service import SimpleMemoryIntent

LOGGER = logging.getLogger("rex.memory.turn")


def log_confirmation_lifecycle(
    event: str,
    intent: SimpleMemoryIntent,
    *,
    conversation_id: str,
    confirmation_id: Optional[str] = None,
    memory_id: Optional[str] = None,
) -> None:
    metadata = intent.metadata if isinstance(intent.metadata, dict) else {}
    payload = {
        "conversation_id": conversation_id,
        "confirmation_id": confirmation_id,
        "memory_id": memory_id,
        "memory_type": intent.memory_type,
        "topic_fingerprint": metadata.get("topic_fingerprint"),
        "fact_kind": metadata.get("fact_kind"),
    }
    LOGGER.info(
        "memory_confirmation_%s %s",
        event,
        json.dumps(payload, sort_keys=True),
    )

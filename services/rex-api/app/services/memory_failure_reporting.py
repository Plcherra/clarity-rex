import json
import logging
from typing import Any, Optional


LOGGER = logging.getLogger("rex.memory.failure")


def memory_degraded_metadata(
    metadata: Optional[dict[str, Any]] = None,
    *,
    operation: str,
    failure_reason: str,
    user_visible: bool = False,
) -> dict[str, Any]:
    """Return privacy-safe metadata for memory flows that degraded."""
    degraded = dict(metadata) if isinstance(metadata, dict) else {}
    degraded["degraded"] = True
    degraded["operation"] = operation
    degraded["failure_reason"] = failure_reason
    degraded["user_visible"] = user_visible
    return degraded


def log_memory_failure(
    event: str,
    *,
    operation: str,
    error: Exception,
    conversation_id: Optional[str] = None,
    action_type: Optional[str] = None,
    memory_type: Optional[str] = None,
    metadata: Optional[dict[str, Any]] = None,
) -> None:
    """Log a memory circuit-breaker failure without leaking user text."""
    safe_metadata = metadata if isinstance(metadata, dict) else {}
    payload = {
        "operation": operation,
        "error_class": type(error).__name__,
        "conversation_id": conversation_id,
        "action_type": action_type,
        "memory_type": memory_type,
        "topic_fingerprint": safe_metadata.get("topic_fingerprint"),
        "fact_kind": safe_metadata.get("fact_kind"),
    }
    LOGGER.warning("memory_failure_%s %s", event, json.dumps(payload, sort_keys=True))

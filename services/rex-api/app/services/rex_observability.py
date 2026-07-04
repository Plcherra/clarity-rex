import json
import logging
from typing import Optional


class MemoryOperationObserver:
    """Metadata-only Memory observability.

    Keep this intentionally narrow: callers may pass operation names, record ids,
    status codes, and exception classes, but not memory content, payload bodies,
    prompts, or user-entered text.
    """

    def __init__(self, logger: Optional[logging.Logger] = None) -> None:
        self.logger = logger or logging.getLogger("rex.memory")

    def log_failure(
        self,
        *,
        operation: str,
        error: Exception,
        memory_id: Optional[str] = None,
        record_id: Optional[str] = None,
        status_code: Optional[int] = None,
    ) -> dict:
        payload = {
            "operation": operation,
            "status": "failed",
            "error_class": type(error).__name__,
        }
        if memory_id:
            payload["memory_id"] = memory_id
        if record_id:
            payload["record_id"] = record_id
        if status_code is not None:
            payload["status_code"] = status_code

        self.logger.warning(
            "memory_operation_failed %s",
            json.dumps(payload, sort_keys=True),
        )
        return payload

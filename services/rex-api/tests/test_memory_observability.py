import json

from app.services.rex_observability import MemoryOperationObserver


class FakeLogger:
    def __init__(self):
        self.records = []

    def info(self, message, *args):
        self.records.append(message % args)

    def warning(self, message, *args):
        self.records.append(message % args)


def test_memory_observer_logs_ids_and_error_class_without_private_content():
    logger = FakeLogger()
    observer = MemoryOperationObserver(logger=logger)

    payload = observer.log_failure(
        operation="save_memory",
        memory_id="memory-1",
        error=RuntimeError("secret memory body should not be logged"),
        status_code=503,
    )

    assert payload == {
        "operation": "save_memory",
        "status": "failed",
        "error_class": "RuntimeError",
        "memory_id": "memory-1",
        "status_code": 503,
    }
    rendered = json.dumps(payload) + "\n" + "\n".join(logger.records)
    assert "secret memory body" not in rendered
    assert "memory_operation_failed" in logger.records[0]

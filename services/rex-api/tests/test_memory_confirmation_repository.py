from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest

from app.services.memory_confirmation_repository import MemoryConfirmationRepository
from app.services.memory_errors import MemoryServiceError
from app.services.memory_service import SupabaseMemoryService


class FakeMemoryConfirmationStore:
    def __init__(self):
        self.settings = SimpleNamespace(
            supabase_memory_confirmations_table="memory_confirmations"
        )
        self.rows = []
        self.created = []
        self.updated = []
        self.requests = []
        self.next_id = 1

    async def _create_record(self, table, body, select):
        self.created.append((table, body, select))
        row = {
            "id": f"confirmation-{self.next_id}",
            "user_id": "user-1",
            "created_at": self._now_iso(),
            "updated_at": self._now_iso(),
            **body,
        }
        self.next_id += 1
        self.rows.append(row)
        return row

    async def _request(self, method, table, query=None, **kwargs):
        self.requests.append((method, table, query, kwargs))
        if method != "GET":
            return []

        conversation_id = _eq_value(query["conversation_id"])
        status = _eq_value(query["status"])
        expires_after = _gt_datetime(query["expires_at"])
        rows = [
            row
            for row in self.rows
            if row.get("conversation_id") == conversation_id
            and row.get("status") == status
            and _parse_datetime(row.get("expires_at")) > expires_after
        ]
        rows.sort(key=lambda row: row["created_at"], reverse=True)
        return rows[: int(query.get("limit", "50"))]

    async def _update_record(self, table, record_id, updates, select, empty_detail):
        if not updates:
            raise MemoryServiceError(empty_detail, 400)
        self.updated.append((table, record_id, updates, select))
        for row in self.rows:
            if row["id"] == record_id:
                row.update({key: value for key, value in updates.items() if value is not None})
                row["updated_at"] = self._now_iso()
                return row
        return None

    def _now_iso(self):
        return datetime.now(timezone.utc).isoformat()


def _future_iso(days=1):
    return (datetime.now(timezone.utc) + timedelta(days=days)).isoformat()


def _past_iso(days=1):
    return (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()


def _parse_datetime(value):
    return datetime.fromisoformat(str(value).replace("Z", "+00:00"))


def _eq_value(value):
    return str(value).removeprefix("eq.")


def _gt_datetime(value):
    return _parse_datetime(str(value).removeprefix("gt."))


@pytest.mark.asyncio
async def test_create_memory_confirmation_defaults_and_persists_payload():
    store = FakeMemoryConfirmationStore()
    repository = MemoryConfirmationRepository(store)

    created = await repository.create_memory_confirmation(
        {
            "conversation_id": "conversation-1",
            "source_message_id": "message-user",
            "memory_type": "fact",
            "content": "User's mom's birthday is June 18.",
            "importance": 5,
            "metadata": {"topic_fingerprint": "fact:birthday:mom"},
        }
    )

    assert created["id"] == "confirmation-1"
    assert created["status"] == "pending"
    assert created["source"] == "simple_memory_intent"
    assert created["metadata"]["topic_fingerprint"] == "fact:birthday:mom"
    assert store.created[0][0] == "memory_confirmations"


@pytest.mark.asyncio
async def test_get_latest_pending_memory_confirmation_filters_expired_rows():
    store = FakeMemoryConfirmationStore()
    repository = MemoryConfirmationRepository(store)
    store.rows.extend(
        [
            {
                "id": "old-valid",
                "conversation_id": "conversation-1",
                "status": "pending",
                "expires_at": _future_iso(),
                "created_at": "2026-06-01T12:00:00+00:00",
            },
            {
                "id": "expired",
                "conversation_id": "conversation-1",
                "status": "pending",
                "expires_at": _past_iso(),
                "created_at": "2026-06-01T13:00:00+00:00",
            },
            {
                "id": "new-valid",
                "conversation_id": "conversation-1",
                "status": "pending",
                "expires_at": _future_iso(),
                "created_at": "2026-06-01T14:00:00+00:00",
            },
        ]
    )

    pending = await repository.get_latest_pending_memory_confirmation(
        "conversation-1"
    )

    assert pending["id"] == "new-valid"
    query = store.requests[0][2]
    assert query["status"] == "eq.pending"
    assert query["expires_at"].startswith("gt.")
    assert query["order"] == "created_at.desc"
    assert query["limit"] == "1"


@pytest.mark.asyncio
async def test_confirmation_lifecycle_updates_status_timestamps_and_metadata():
    store = FakeMemoryConfirmationStore()
    repository = MemoryConfirmationRepository(store)
    store.rows.append(
        {
            "id": "confirmation-1",
            "conversation_id": "conversation-1",
            "status": "pending",
            "expires_at": _future_iso(),
            "created_at": "2026-06-01T12:00:00+00:00",
        }
    )

    confirmed = await repository.confirm_memory_confirmation(
        "confirmation-1",
        applied_memory_id="memory-1",
        metadata={"saved": True},
    )

    assert confirmed["status"] == "confirmed"
    assert confirmed["confirmed_at"] is not None
    assert confirmed["applied_memory_id"] == "memory-1"
    assert confirmed["metadata"] == {"saved": True}

    rejected = await repository.reject_memory_confirmation("confirmation-1")
    assert rejected["status"] == "rejected"
    assert rejected["rejected_at"] is not None

    expired = await repository.expire_memory_confirmation("confirmation-1")
    assert expired["status"] == "expired"

    failed = await repository.fail_memory_confirmation(
        "confirmation-1",
        metadata={"error": "write failed"},
    )
    assert failed["status"] == "failed"
    assert failed["failed_at"] is not None
    assert failed["metadata"] == {"error": "write failed"}


@pytest.mark.asyncio
async def test_memory_confirmation_repository_validates_inputs():
    store = FakeMemoryConfirmationStore()
    repository = MemoryConfirmationRepository(store)

    with pytest.raises(MemoryServiceError):
        await repository.create_memory_confirmation(
            {
                "conversation_id": "conversation-1",
                "memory_type": "personal_fact",
                "content": "User's mom's birthday is June 18.",
            }
        )

    with pytest.raises(MemoryServiceError):
        await repository.create_memory_confirmation(
            {
                "conversation_id": "conversation-1",
                "memory_type": "fact",
                "content": "",
            }
        )

    with pytest.raises(MemoryServiceError):
        await repository.update_memory_confirmation(
            "confirmation-1",
            status="waiting",
        )


@pytest.mark.asyncio
async def test_memory_service_facade_delegates_to_confirmation_repository():
    class FakeConfirmationRepository:
        async def create_memory_confirmation(self, confirmation):
            return {"id": "confirmation-1", **confirmation}

        async def get_latest_pending_memory_confirmation(self, conversation_id):
            return {"id": "confirmation-1", "conversation_id": conversation_id}

    service = SupabaseMemoryService()
    service.memory_confirmation_repository = FakeConfirmationRepository()

    created = await service.create_memory_confirmation(
        {
            "conversation_id": "conversation-1",
            "memory_type": "fact",
            "content": "User's mom's birthday is June 18.",
        }
    )
    pending = await service.get_latest_pending_memory_confirmation("conversation-1")

    assert created["id"] == "confirmation-1"
    assert pending["conversation_id"] == "conversation-1"

import pytest

from app.services.long_term_memory_repository import LongTermMemoryRepository


class FakeStore:
    def __init__(self):
        self.settings = type(
            "Settings",
            (),
            {"supabase_long_term_memory_table": "long_term_memory"},
        )()
        self.requests = []

    async def _request(self, method, table, *, body=None, query=None, prefer=None):
        self.requests.append(
            {
                "method": method,
                "table": table,
                "body": body,
                "query": query,
                "prefer": prefer,
            }
        )
        return [{**body, "id": "memory-1", "active": True}]

    def _first_row(self, rows):
        return rows[0]

    async def _update_record(
        self,
        table,
        record_id,
        *,
        updates,
        select,
        empty_detail,
    ):
        self.requests.append(
            {
                "method": "PATCH",
                "table": table,
                "id": record_id,
                "updates": updates,
                "select": select,
                "empty_detail": empty_detail,
            }
        )
        if not updates:
            return None
        return {**updates, "id": record_id, "active": updates.get("active", True)}


@pytest.mark.asyncio
async def test_save_long_term_memory_adds_category_metadata():
    store = FakeStore()
    repository = LongTermMemoryRepository(store)

    memory = await repository.save_long_term_memory(
        memory_type="fact",
        content="User lives in Somerville.",
        metadata={"fact_kind": "location"},
    )

    assert memory["metadata"]["memory_category"] == "Places"
    assert store.requests[0]["body"]["metadata"]["memory_category"] == "Places"


@pytest.mark.asyncio
async def test_save_long_term_memory_preserves_explicit_other_category():
    store = FakeStore()
    repository = LongTermMemoryRepository(store)

    memory = await repository.save_long_term_memory(
        memory_type="fact",
        content="User shared a custom saved detail.",
        metadata={"memory_category": "Other"},
    )

    assert memory["metadata"]["memory_category"] == "Other"


@pytest.mark.asyncio
async def test_update_long_term_memory_normalizes_category_metadata():
    store = FakeStore()
    repository = LongTermMemoryRepository(store)

    memory = await repository.update_long_term_memory(
        "memory-1",
        memory_type="fact",
        content="User lives in Cambridge.",
        metadata={"memory_category": "invalid"},
    )

    assert memory is not None
    assert memory["metadata"]["memory_category"] == "Places"


@pytest.mark.asyncio
async def test_save_long_term_memory_from_message_does_not_auto_save_chat():
    store = FakeStore()
    repository = LongTermMemoryRepository(store)

    memory = await repository.save_long_term_memory_from_message(
        "conversation-1",
        {
            "id": "message-1",
            "content": "My mom's birthday is June 18.",
        },
    )

    assert memory is None
    assert store.requests == []

from __future__ import annotations

import pytest

from app.models.open_thread import MAX_ACTIVE_OPEN_THREADS, OpenThreadCreateRequest
from app.services.open_thread_service import OpenThreadService
from app.services.open_thread_turn_service import (
    THREAD_OFFER_PHRASE,
    OpenThreadTurnService,
)
from test_open_thread_service import FakeOpenThreadStore


class FakeTurnMemoryService:
    def __init__(self) -> None:
        self.messages: list[dict] = []

    async def save_message(self, conversation_id, role, content):
        message = {
            "id": f"message-{len(self.messages) + 1}",
            "conversation_id": conversation_id,
            "role": role,
            "content": content,
        }
        self.messages.append(message)
        return message

    async def get_conversation_messages(self, conversation_id, limit=50):
        return [
            message
            for message in self.messages
            if message["conversation_id"] == conversation_id
        ][-limit:]

    async def get_recent_messages(self, conversation_id, limit=20):
        return await self.get_conversation_messages(conversation_id, limit=limit)

    async def list_plans(self, active=True, limit=20):
        return []

    async def list_long_term_memory(self, active=True, limit=30):
        return []

    async def list_entities(self, active=True, limit=30):
        return []


class FakeTurnMemoryServiceWithContext(FakeTurnMemoryService):
    def __init__(
        self,
        *,
        plans=None,
        memories=None,
        entities=None,
    ) -> None:
        super().__init__()
        self._plans = plans or []
        self._memories = memories or []
        self._entities = entities or []

    async def list_plans(self, active=True, limit=20):
        return self._plans[:limit]

    async def list_long_term_memory(self, active=True, limit=30):
        return self._memories[:limit]

    async def list_entities(self, active=True, limit=30):
        return self._entities[:limit]


class FakeDurableWriteService:
    def __init__(self) -> None:
        self.proposals: list[dict] = []

    async def propose_open_thread(self, **kwargs):
        self.proposals.append(kwargs)
        response = kwargs.get("response") or (
            "Just to confirm — track this in Goals as an open thread?"
        )
        return {
            "response": response,
            "conversation_id": kwargs["conversation_id"],
            "memory_changes": {
                "confirmation_required": 1,
                "write_proposals": [
                    {
                        "id": "open-thread-proposal-1",
                        "write_kind": "open_thread",
                        "title": kwargs["title"],
                    }
                ],
            },
        }


@pytest.mark.asyncio
async def test_open_thread_turn_service_offers_once_for_eligible_message():
    memory = FakeTurnMemoryService()
    store = FakeOpenThreadStore()
    threads = OpenThreadService(store)
    durable = FakeDurableWriteService()
    service = OpenThreadTurnService(
        memory,
        open_thread_service=threads,
        durable_write_service=durable,
    )

    result = await service.handle_turn(
        "I've been trying to figure out a better morning routine lately.",
        conversation_id="conversation-1",
        user_message={"id": "user-1", "content": "I've been trying to figure out a better morning routine lately."},
        conversation_history=[],
    )

    assert result is not None
    assert THREAD_OFFER_PHRASE in result["response"]
    assert "not saved memory" in result["response"]
    assert result["memory_changes"]["confirmation_required"] == 0
    assert not result["memory_changes"].get("write_proposals")
    assert not durable.proposals


@pytest.mark.asyncio
async def test_open_thread_turn_service_proposes_after_yes():
    memory = FakeTurnMemoryService()
    store = FakeOpenThreadStore()
    threads = OpenThreadService(store)
    durable = FakeDurableWriteService()
    service = OpenThreadTurnService(
        memory,
        open_thread_service=threads,
        durable_write_service=durable,
    )
    history = [
        {
            "role": "user",
            "content": "I've been trying to figure out a better morning routine lately.",
        },
        {
            "role": "assistant",
            "content": (
                f"{THREAD_OFFER_PHRASE} It would show up in your Goals tab as an open thread — "
                "not saved memory."
            ),
        },
    ]

    result = await service.handle_turn(
        "Yes",
        conversation_id="conversation-1",
        user_message={"id": "user-2", "content": "Yes"},
        conversation_history=history,
    )

    assert result is not None
    assert result["memory_changes"]["confirmation_required"] == 1
    assert durable.proposals[0]["title"] == "Better Morning Routine"
    summary = durable.proposals[0]["summary"]
    assert summary is not None
    assert summary.startswith("Follow up on")
    assert summary != durable.proposals[0]["title"]


@pytest.mark.asyncio
async def test_open_thread_turn_service_declines_bare_no_after_offer():
    memory = FakeTurnMemoryService()
    service = OpenThreadTurnService(
        memory,
        open_thread_service=OpenThreadService(FakeOpenThreadStore()),
        durable_write_service=FakeDurableWriteService(),
    )
    history = [
        {
            "role": "user",
            "content": "I've been working through a stressful move across town lately.",
        },
        {
            "role": "assistant",
            "content": f"{THREAD_OFFER_PHRASE} not saved memory.",
        },
    ]

    result = await service.handle_turn(
        "No",
        conversation_id="conversation-1",
        user_message={"id": "user-2", "content": "No"},
        conversation_history=history,
    )

    assert result is not None
    assert "won't track" in result["response"].lower()


@pytest.mark.asyncio
async def test_open_thread_turn_service_offers_close_or_replace_at_cap():
    memory = FakeTurnMemoryService()
    store = FakeOpenThreadStore()
    threads = OpenThreadService(store)
    for index in range(MAX_ACTIVE_OPEN_THREADS):
        await threads.create_thread(
            OpenThreadCreateRequest(title=f"Thread {index}", summary="ongoing")
        )
    service = OpenThreadTurnService(
        memory,
        open_thread_service=threads,
        durable_write_service=FakeDurableWriteService(),
    )

    result = await service.handle_turn(
        "I've been trying to figure out a better morning routine lately.",
        conversation_id="conversation-1",
        user_message={
            "id": "user-1",
            "content": "I've been trying to figure out a better morning routine lately.",
        },
        conversation_history=[],
    )

    assert result is not None
    assert "5 active open threads" in result["response"]
    assert "close or pause" in result["response"].lower()
    assert "not saved memory" in result["response"].lower()


@pytest.mark.asyncio
async def test_open_thread_turn_service_skips_offer_when_thread_topic_overlaps():
    memory = FakeTurnMemoryServiceWithContext()
    store = FakeOpenThreadStore()
    threads = OpenThreadService(store)
    await threads.create_thread(
        OpenThreadCreateRequest(
            title="Rebuild my workout habit this month",
            summary="ongoing fitness",
        )
    )
    service = OpenThreadTurnService(
        memory,
        open_thread_service=threads,
        durable_write_service=FakeDurableWriteService(),
    )

    result = await service.handle_turn(
        "I've been trying to rebuild my workout habit this month.",
        conversation_id="conversation-1",
        user_message={
            "id": "user-1",
            "content": "I've been trying to rebuild my workout habit this month.",
        },
        conversation_history=[],
    )

    assert result is None


@pytest.mark.asyncio
async def test_open_thread_turn_service_skips_offer_when_plan_topic_overlaps():
    memory = FakeTurnMemoryServiceWithContext(
        plans=[
            {
                "title": "Morning routine reset",
                "description": "Building a better morning routine lately.",
            }
        ]
    )
    service = OpenThreadTurnService(
        memory,
        open_thread_service=OpenThreadService(FakeOpenThreadStore()),
        durable_write_service=FakeDurableWriteService(),
    )

    result = await service.handle_turn(
        "I've been trying to figure out a better morning routine lately.",
        conversation_id="conversation-1",
        user_message={
            "id": "user-1",
            "content": "I've been trying to figure out a better morning routine lately.",
        },
        conversation_history=[],
    )

    assert result is None


@pytest.mark.asyncio
async def test_open_thread_turn_service_skips_offer_when_saved_memory_overlaps():
    memory = FakeTurnMemoryServiceWithContext(
        memories=[
            {
                "content": "User has been working through a stressful move across town lately.",
            }
        ]
    )
    service = OpenThreadTurnService(
        memory,
        open_thread_service=OpenThreadService(FakeOpenThreadStore()),
        durable_write_service=FakeDurableWriteService(),
    )

    result = await service.handle_turn(
        "I've been working through a stressful move across town lately.",
        conversation_id="conversation-1",
        user_message={
            "id": "user-1",
            "content": "I've been working through a stressful move across town lately.",
        },
        conversation_history=[],
    )

    assert result is None

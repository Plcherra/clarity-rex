from __future__ import annotations

import pytest

from app.models.open_thread import MAX_ACTIVE_OPEN_THREADS, OpenThreadCreateRequest
from app.services.assistant_proposal_settings import AssistantProposalSettings
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
        self.applied_consents: list[dict] = []
        self.update_proposals: list[dict] = []
        self.applied_updates: list[dict] = []

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

    async def apply_open_thread_consent(self, **kwargs):
        self.applied_consents.append(kwargs)
        return {
            "response": f'Tracked "{kwargs["title"]}" as an open thread in Goals.',
            "conversation_id": kwargs["conversation_id"],
            "memory_changes": {
                "confirmation_required": 0,
                "created": 1,
                "write_proposals": [],
            },
        }

    async def propose_open_thread_update(self, **kwargs):
        self.update_proposals.append(kwargs)
        return {
            "response": (
                f'Update open thread "{kwargs.get("existing_title")}" to:\n'
                f'{kwargs["title"]}'
            ),
            "conversation_id": kwargs["conversation_id"],
            "memory_changes": {
                "confirmation_required": 1,
                "write_proposals": [
                    {
                        "id": "open-thread-update-1",
                        "write_kind": "open_thread",
                        "title": kwargs["title"],
                        "target_label": kwargs.get("existing_title"),
                    }
                ],
            },
        }

    async def apply_open_thread_update_consent(self, **kwargs):
        self.applied_updates.append(kwargs)
        return {
            "response": f'Updated open thread to "{kwargs["title"]}" in Goals.',
            "conversation_id": kwargs["conversation_id"],
            "memory_changes": {
                "confirmation_required": 0,
                "updated": 1,
                "write_proposals": [],
            },
        }


@pytest.mark.asyncio
async def test_open_thread_turn_service_offers_text_for_clear_plan():
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
        proposal_settings=AssistantProposalSettings(mode="text"),
    )

    assert result is not None
    assert THREAD_OFFER_PHRASE in result["response"]
    assert result["memory_changes"]["confirmation_required"] == 0
    assert not result["memory_changes"].get("write_proposals")
    assert not durable.proposals


@pytest.mark.asyncio
async def test_open_thread_turn_service_proposes_card_when_mode_is_card():
    from app.services.assistant_proposal_settings import AssistantProposalSettings

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
        proposal_settings=AssistantProposalSettings(mode="card"),
    )

    assert result is not None
    assert result["memory_changes"]["confirmation_required"] == 1
    assert result["memory_changes"]["write_proposals"][0]["write_kind"] == "open_thread"
    assert durable.proposals[0]["title"] == "Better Morning Routine"


@pytest.mark.asyncio
async def test_open_thread_turn_service_offers_once_for_eligible_companion_topic():
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
        "I'm working on my citizenship application and it has been really stressful lately.",
        conversation_id="conversation-1",
        user_message={
            "id": "user-1",
            "content": "I'm working on my citizenship application and it has been really stressful lately.",
        },
        conversation_history=[],
        proposal_settings=AssistantProposalSettings(mode="text"),
    )

    assert result is not None
    assert THREAD_OFFER_PHRASE in result["response"]
    assert "not saved memory" in result["response"]
    assert result["memory_changes"]["confirmation_required"] == 0
    assert not result["memory_changes"].get("write_proposals")
    assert not durable.proposals


@pytest.mark.asyncio
async def test_open_thread_turn_service_applies_after_yes_in_text_mode():
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
        proposal_settings=AssistantProposalSettings(mode="text"),
    )

    assert result is not None
    assert result["memory_changes"]["confirmation_required"] == 0
    assert not result["memory_changes"].get("write_proposals")
    assert durable.applied_consents[0]["title"] == "Better Morning Routine"
    assert durable.proposals == []


@pytest.mark.asyncio
async def test_open_thread_turn_service_proposes_card_after_yes_in_card_mode():
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
        proposal_settings=AssistantProposalSettings(mode="card"),
    )

    assert result is not None
    assert result["memory_changes"]["confirmation_required"] == 1
    assert durable.proposals[0]["title"] == "Better Morning Routine"
    summary = durable.proposals[0]["summary"]
    assert summary is not None
    assert summary.startswith("Follow up on")
    assert summary != durable.proposals[0]["title"]
    assert durable.applied_consents == []


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
        proposal_settings=AssistantProposalSettings(mode="text"),
    )

    assert result is not None
    assert "5 active open threads" in result["response"]
    assert "close or pause" in result["response"].lower()
    assert "not saved memory" in result["response"].lower()


@pytest.mark.asyncio
async def test_open_thread_turn_service_skips_offer_when_thread_topic_overlaps():
    """Off mode: overlapping topic must not auto-suggest create or update."""
    memory = FakeTurnMemoryServiceWithContext()
    store = FakeOpenThreadStore()
    threads = OpenThreadService(store)
    await threads.create_thread(
        OpenThreadCreateRequest(
            title="Rebuild my workout habit this month",
            summary="ongoing fitness",
        )
    )
    durable = FakeDurableWriteService()
    service = OpenThreadTurnService(
        memory,
        open_thread_service=threads,
        durable_write_service=durable,
    )

    result = await service.handle_turn(
        "I've been trying to rebuild my workout habit this month.",
        conversation_id="conversation-1",
        user_message={
            "id": "user-1",
            "content": "I've been trying to rebuild my workout habit this month.",
        },
        conversation_history=[],
        proposal_settings=AssistantProposalSettings(mode="off"),
    )

    assert result is None
    assert durable.update_proposals == []
    assert durable.proposals == []


SLEEP_THREAD_TITLE = "Sleep Schedule and Wake Up Everyday At 3am"
SLEEP_THREAD_SUMMARY = "wake up every day at 3am"
WAKE_6AM_MESSAGE = (
    "I want to change my sleep schedule and wake up every day at 6am instead."
)


async def _service_with_sleep_thread():
    memory = FakeTurnMemoryService()
    store = FakeOpenThreadStore()
    threads = OpenThreadService(store)
    created = await threads.create_thread(
        OpenThreadCreateRequest(
            title=SLEEP_THREAD_TITLE,
            summary=SLEEP_THREAD_SUMMARY,
        )
    )
    durable = FakeDurableWriteService()
    service = OpenThreadTurnService(
        memory,
        open_thread_service=threads,
        durable_write_service=durable,
    )
    return service, durable, created


@pytest.mark.asyncio
async def test_overlap_text_mode_asks_to_update_existing_thread():
    from app.services.open_thread_turn_update import THREAD_UPDATE_ASK_MARKER

    service, durable, created = await _service_with_sleep_thread()
    result = await service.handle_turn(
        WAKE_6AM_MESSAGE,
        conversation_id="conversation-1",
        user_message={"id": "user-1", "content": WAKE_6AM_MESSAGE},
        conversation_history=[],
        proposal_settings=AssistantProposalSettings(mode="text"),
    )

    assert result is not None
    assert THREAD_UPDATE_ASK_MARKER in result["response"]
    assert "3am" in result["response"].lower() or SLEEP_THREAD_TITLE in result["response"]
    assert result["memory_changes"]["confirmation_required"] == 0
    assert not result["memory_changes"].get("write_proposals")
    assert durable.update_proposals == []
    assert durable.proposals == []
    assert created["id"]


@pytest.mark.asyncio
async def test_overlap_card_mode_proposes_thread_update():
    service, durable, created = await _service_with_sleep_thread()
    result = await service.handle_turn(
        WAKE_6AM_MESSAGE,
        conversation_id="conversation-1",
        user_message={"id": "user-1", "content": WAKE_6AM_MESSAGE},
        conversation_history=[],
        proposal_settings=AssistantProposalSettings(mode="card"),
    )

    assert result is not None
    assert result["memory_changes"]["confirmation_required"] == 1
    assert result["memory_changes"]["write_proposals"][0]["write_kind"] == "open_thread"
    assert durable.update_proposals
    assert durable.update_proposals[0]["thread_id"] == created["id"]
    assert durable.proposals == []


@pytest.mark.asyncio
async def test_overlap_off_mode_does_not_auto_suggest_update():
    service, durable, _created = await _service_with_sleep_thread()
    result = await service.handle_turn(
        WAKE_6AM_MESSAGE,
        conversation_id="conversation-1",
        user_message={"id": "user-1", "content": WAKE_6AM_MESSAGE},
        conversation_history=[],
        proposal_settings=AssistantProposalSettings(mode="off"),
    )

    assert result is None
    assert durable.update_proposals == []
    assert durable.applied_updates == []
    assert durable.proposals == []


@pytest.mark.asyncio
async def test_explicit_update_works_under_off_mode():
    service, durable, created = await _service_with_sleep_thread()
    message = "update my 3am thread to 5am instead"
    result = await service.handle_turn(
        message,
        conversation_id="conversation-1",
        user_message={"id": "user-1", "content": message},
        conversation_history=[],
        proposal_settings=AssistantProposalSettings(mode="off"),
    )

    assert result is not None
    assert result["memory_changes"]["confirmation_required"] == 1
    assert durable.update_proposals
    assert durable.update_proposals[0]["thread_id"] == created["id"]
    assert durable.proposals == []


@pytest.mark.asyncio
async def test_text_yes_after_update_ask_applies_update():
    from app.services.open_thread_turn_update import build_thread_update_ask

    service, durable, created = await _service_with_sleep_thread()
    ask = build_thread_update_ask(
        existing_title=SLEEP_THREAD_TITLE,
        new_title="Wake Up Everyday At 6am",
    )
    history = [
        {"role": "user", "content": WAKE_6AM_MESSAGE},
        {"role": "assistant", "content": ask},
    ]
    result = await service.handle_turn(
        "Yes",
        conversation_id="conversation-1",
        user_message={"id": "user-2", "content": "Yes"},
        conversation_history=history,
        proposal_settings=AssistantProposalSettings(mode="text"),
    )

    assert result is not None
    assert result["memory_changes"].get("updated") == 1
    assert durable.applied_updates
    assert durable.applied_updates[0]["thread_id"] == created["id"]
    assert durable.update_proposals == []


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

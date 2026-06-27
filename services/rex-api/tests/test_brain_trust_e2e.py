"""End-to-end brain trust regression tests through ChatService."""

from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from chat_service_fakes import FakeAIService, FakeMemoryService
from app.services.chat_service import ChatService
from app.services.chat_turn_observability import ChatTurnObserver
from app.services.file_service import FileService
from app.services.time_context_service import TimeContextService


def _fixed_time_context_service():
    return TimeContextService(
        timezone_name="America/New_York",
        now_provider=lambda: datetime(
            2026,
            6,
            1,
            12,
            0,
            tzinfo=ZoneInfo("America/New_York"),
        ),
    )


class CapturingTurnObserver(ChatTurnObserver):
    def __init__(self) -> None:
        super().__init__()
        self.logged: list[dict] = []

    def log_turn(self, trace):
        payload = super().log_turn(trace)
        self.logged.append(payload)
        return payload


@pytest.mark.asyncio
async def test_yes_delete_uses_stored_pending_action_not_history():
    ai_service = FakeAIService(response="Rex should not answer")
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.extend(
        [
            {
                "id": "memory-game-note",
                "memory_type": "fact",
                "content": "User loves Legacy of Kain.",
                "importance": 4,
                "active": True,
            },
            {
                "id": "memory-birthday-note",
                "memory_type": "fact",
                "content": "User mom birthday is June 18.",
                "importance": 4,
                "active": True,
            },
        ]
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )
    conversation_id = await memory_service.create_conversation()
    memory_service.pending_actions[conversation_id] = {
        "action_type": "delete",
        "target_type": "long_term_memory",
        "target_id": "memory-game-note",
        "target_label": "Legacy of Kain",
        "resolver_target": "Legacy of Kain",
        "scope_tables": ["long_term_memory"],
    }
    await memory_service.save_message(
        conversation_id,
        "assistant",
        (
            "Got it--you want to delete this saved memory: User mom birthday is June 18.\n\n"
            "Just to confirm before I do that: yes or no?"
        ),
    )

    confirmed = await chat_service.send_message("Yes delete it", conversation_id)

    assert confirmed["memory_changes"]["archived"] == 1
    assert memory_service.long_term_memory[0]["active"] is False
    assert memory_service.long_term_memory[1]["active"] is True
    assert memory_service.memory_corrections[0]["target_id"] == "memory-game-note"
    assert conversation_id not in memory_service.pending_actions
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_inventory_after_failed_delete_via_chat_service():
    ai_service = FakeAIService(response="Rex should not answer")
    memory_service = FakeMemoryService()
    memory_service.commitments.append(
        {
            "id": "commitment-1",
            "title": "Wake at 5 AM",
            "commitment_text": "Wake at 5 AM",
            "status": "open",
            "active": True,
        }
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    failed = await chat_service.send_message('Delete the commitment "Missing title"')
    inventory = await chat_service.send_message(
        "What commitments do we have saved?",
        failed["conversation_id"],
    )

    assert "didn't delete anything" in failed["response"]
    assert "Open commitments:" in inventory["response"]
    assert "Wake at 5 AM" in inventory["response"]
    assert "Just to confirm" not in inventory["response"]
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_stream_inventory_short_circuit_logs_goal_command_handler():
    ai_service = FakeAIService(stream_tokens=["unused"])
    memory_service = FakeMemoryService()
    memory_service.commitments.append(
        {
            "id": "commitment-1",
            "title": "Wake at 5 AM",
            "commitment_text": "Wake at 5 AM",
            "status": "open",
            "active": True,
        }
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )
    observer = CapturingTurnObserver()
    chat_service.turn_orchestrator.turn_observer = observer

    events = [
        event
        async for event in chat_service.stream_message(
            "What commitments do we have saved?"
        )
    ]

    assert events[-1]["event"] == "done"
    assert "Open commitments:" in events[-1]["response"]
    assert observer.logged[-1]["handler"] == "goal_command"
    assert ai_service.stream_calls == 0


@pytest.mark.asyncio
async def test_delete_that_after_assistant_names_commitment_on_goals_tab():
    ai_service = FakeAIService(response="Rex should not answer")
    memory_service = FakeMemoryService()
    memory_service.commitments.append(
        {
            "id": "commitment-junk",
            "title": "Be a goal/commitment",
            "commitment_text": "be a goal/commitment",
            "commitment_type": "task",
            "status": "open",
            "active": True,
        }
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )
    conversation_id = await memory_service.create_conversation()
    await memory_service.save_message(
        conversation_id,
        "assistant",
        (
            "There's also a test commitment called 'Be a goal/commitment' "
            "saved on the goals tab."
        ),
    )

    requested = await chat_service.send_message(
        "You delete that, please?",
        conversation_id,
    )
    confirmed = await chat_service.send_message("Yes", conversation_id)

    assert "Just to confirm" in requested["response"]
    assert "commitment" in requested["response"].lower()
    assert "Be a goal/commitment" in requested["response"]
    assert confirmed["memory_changes"]["archived"] == 1
    assert memory_service.commitments[0]["active"] is False
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_saved_on_goals_inventory_uses_goal_command_handler():
    ai_service = FakeAIService(response="Rex should not answer")
    memory_service = FakeMemoryService()
    memory_service.plans.extend(
        [
            {
                "id": "plan-ram",
                "title": "Buy 32-64 GB of RAM",
                "status": "active",
                "active": True,
            },
            {
                "id": "plan-storage",
                "title": "Buy 1-2 TB of storage",
                "status": "active",
                "active": True,
            },
        ]
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    result = await chat_service.send_message("What do you have saved on goals?")

    assert "Active goals:" in result["response"]
    assert "Buy 32-64 GB of RAM" in result["response"]
    assert "Buy 1-2 TB of storage" in result["response"]
    assert ai_service.messages == []

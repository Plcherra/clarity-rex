from __future__ import annotations

import pytest

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.auto_suggestions_gate import apply_auto_suggestions_gate
from app.services.brain_action_schema import BrainAction, parse_brain_actions
from app.services.capability_dispatcher import dispatch_allowed_actions
from app.services.capabilities.open_thread_title import title_from_user_text
from app.services.durable_write_service import DurableWriteService


class _FakeMemoryService:
    def __init__(self) -> None:
        self.user_id = "user-1"
        self.access_token = "token"
        self.pending: dict[str, object] = {}
        self.messages: list[dict] = []
        self.rows: list[dict] = [
            {
                "id": "thread-wake",
                "title": "Wake at 5:15am",
                "status": "active",
                "summary": "Morning wake-up reminder",
                "user_id": "user-1",
            },
            {
                "id": "thread-gym",
                "title": "Gym three times a week",
                "status": "active",
                "summary": "Strength training",
                "user_id": "user-1",
            },
        ]

    async def get_conversation_pending_action(self, conversation_id: str):
        return self.pending.get(conversation_id)

    async def set_conversation_pending_action(self, conversation_id: str, pending_action):
        if pending_action is None:
            self.pending.pop(conversation_id, None)
        else:
            self.pending[conversation_id] = pending_action

    async def save_message(self, conversation_id: str, role: str, content: str) -> dict:
        message = {
            "id": f"msg-{len(self.messages) + 1}",
            "conversation_id": conversation_id,
            "role": role,
            "content": content,
        }
        self.messages.append(message)
        return message

    async def get_recent_messages(self, conversation_id: str, limit: int = 20) -> list[dict]:
        _ = conversation_id
        return list(self.messages)[-limit:]

    async def _list_records(self, table: str, **kwargs) -> list[dict]:
        if table != "open_threads":
            return []
        filters = kwargs.get("filters") or {}
        rows = list(self.rows)
        status = filters.get("status")
        if status is not None:
            rows = [row for row in rows if row.get("status") == status]
        thread_id = filters.get("id")
        if thread_id is not None:
            rows = [row for row in rows if row.get("id") == thread_id]
        return rows[: int(kwargs.get("limit") or 50)]

    async def _create_record(self, table: str, body: dict, select: str) -> dict:
        _ = table, select
        row = {
            "id": f"thread-{len(self.rows) + 1}",
            **body,
            "created_at": "2026-07-21T00:00:00Z",
            "updated_at": "2026-07-21T00:00:00Z",
        }
        self.rows.append(row)
        return row

    async def _update_record(
        self,
        table: str,
        record_id: str,
        *,
        updates: dict,
        select: str,
        empty_detail: str,
    ) -> dict | None:
        _ = table, select, empty_detail
        for row in self.rows:
            if row.get("id") == record_id:
                row.update(updates)
                row["updated_at"] = "2026-07-21T01:00:00Z"
                return row
        return None


@pytest.mark.asyncio
async def test_off_mode_explicit_command_applies_without_confirmation() -> None:
    memory = _FakeMemoryService()
    durable = DurableWriteService(memory_service=memory)
    settings = AssistantProposalSettings(mode="off", threads=True)
    action = BrainAction(
        name="update_open_thread",
        payload={
            "thread_id": "thread-wake",
            "title": "Wake at 5am",
            "summary": "Work on Clarity every morning",
        },
        explicit=True,
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="Can you update my wake thread to 5am and remind me to work on Clarity?",
    )

    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={
            "id": "u1",
            "content": "Can you update my wake thread to 5am and remind me to work on Clarity?",
        },
        assistant_reply="That sounds more realistic for the morning rhythm.",
    )

    assert result is not None
    assert result["memory_changes"]["confirmation_required"] == 0
    assert result["memory_changes"]["updated"] == 1
    assert memory.rows[0]["title"] == "Wake at 5am"
    assert memory.rows[0]["summary"] == "Work on Clarity every morning"
    assert not memory.pending
    assert "updated in goals" in result["response"].lower()


def test_off_mode_drops_command_shaped_message_without_explicit_flag() -> None:
    settings = AssistantProposalSettings(mode="off", threads=True)
    action = BrainAction(
        name="update_open_thread",
        payload={
            "thread_id": "thread-wake",
            "title": "Wake at 5am",
        },
        explicit=False,
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="Can you update my wake thread to 5am?",
    )
    assert gate.dropped_soft_actions
    assert not gate.allowed_soft_actions


@pytest.mark.asyncio
async def test_text_mode_matches_existing_thread_before_creating_duplicate() -> None:
    memory = _FakeMemoryService()
    durable = DurableWriteService(memory_service=memory)
    settings = AssistantProposalSettings(mode="text", threads=True)
    action = BrainAction(
        name="create_open_thread",
        payload={
            "title": "Clarity",
            "summary": "Work on the app every day at 5:15am",
        },
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="Can you update the thread we have to remind me to work on the app every day at 5:15am?",
    )

    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={
            "id": "u1",
            "content": "Can you update the thread we have to remind me to work on the app every day at 5:15am?",
        },
        assistant_reply="I can tighten that routine up.",
    )

    assert result is not None
    assert result["memory_changes"]["text_confirmation_pending"] is True
    pending = memory.pending["c1"]
    proposal = pending["context"]["durable_write_proposal"]
    assert proposal["apply_snapshot"]["type"] == "open_thread_update"
    assert proposal["apply_snapshot"]["payload"]["thread_id"] == "thread-wake"
    assert proposal["title"] == "Clarity"
    assert proposal["body"] == "Work on the app every day at 5:15am"


@pytest.mark.asyncio
async def test_update_without_new_title_reuses_existing_title_and_summary_card_field() -> None:
    memory = _FakeMemoryService()
    memory.rows = [memory.rows[0]]
    durable = DurableWriteService(memory_service=memory)
    settings = AssistantProposalSettings(mode="card", threads=True)
    action = BrainAction(
        name="update_open_thread",
        payload={"summary": "Work on Clarity every morning"},
    )
    gate = apply_auto_suggestions_gate(
        [action],
        settings,
        user_message="Can you update that thread to remind me to work on Clarity every morning?",
    )

    result = await dispatch_allowed_actions(
        gate=gate,
        settings=settings,
        durable_write_service=durable,
        conversation_id="c1",
        user_message={
            "id": "u1",
            "content": "Can you update that thread to remind me to work on Clarity every morning?",
        },
        assistant_reply="I can prep that change for you.",
    )

    assert result is not None
    proposal = result["memory_changes"]["write_proposals"][0]
    assert proposal["title"] == "Wake at 5:15am"
    assert proposal["body"] == "Work on Clarity every morning"
    assert proposal["editable_fields"] == ["title", "body"]
    assert proposal["payload"]["summary"] == "Work on Clarity every morning"


def test_parse_brain_action_accepts_thread_aliases() -> None:
    parsed = parse_brain_actions(
        "```rex_action\n"
        '{"action":"update_thread","threadId":"thread-wake","title":"Wake at 5am","reason":"Work on Clarity every morning"}\n'
        "```"
    )

    assert len(parsed.actions) == 1
    action = parsed.actions[0]
    assert action.name == "update_open_thread"
    assert action.payload["thread_id"] == "thread-wake"
    assert action.payload["summary"] == "Work on Clarity every morning"


def test_title_from_user_text_extracts_named_title_reply() -> None:
    assert title_from_user_text("The title can be Clarity") == "Clarity"

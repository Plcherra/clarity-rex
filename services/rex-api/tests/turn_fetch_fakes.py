"""Shared fakes for turns that fetch before answering (plan 05 §5)."""

from __future__ import annotations

import json
from types import SimpleNamespace

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.capability_tools import TOOL_NAME
from app.services.chat_response_truth import ChatResponseTruthService
from app.services.chat_turn_fetch import build_fetch_runner
from app.services.chat_turn_finalize import finalize_grok_turn
from app.services.clarity_action_parser import ClarityActionParser
from app.services.durable_write_service import DurableWriteService


class NoPendingStore:
    """Minimal store so finalize can run Truth without durable writes."""

    def __init__(self) -> None:
        self.user_id = "user-1"
        self.access_token = "token"
        self.pending: dict = {}
        self.messages: list[dict] = []

    async def get_conversation_pending_action(self, conversation_id: str):
        return self.pending.get(conversation_id)

    async def set_conversation_pending_action(
        self,
        conversation_id: str,
        pending_action,
    ) -> None:
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

    async def get_recent_messages(self, conversation_id: str, limit: int = 20) -> list:
        _ = conversation_id
        return list(self.messages)[-limit:]

    async def _list_records(self, table: str, **kwargs) -> list[dict]:
        _ = table, kwargs
        return []


class FakeGrokBrain:
    def __init__(self, text: str = "Grounded answer.") -> None:
        self.text = text
        self.calls: list[list[dict]] = []

    async def generate(self, messages, *, max_tokens=None):
        _ = max_tokens
        self.calls.append(list(messages))
        return SimpleNamespace(text=self.text, usage=None)

    @property
    def last_fetch_pack(self) -> str:
        return self.calls[-1][-1]["content"]


class FakeUsageRecorder:
    def __init__(self) -> None:
        self.records: list[dict] = []

    async def record_llm_usage(self, **kwargs) -> None:
        self.records.append(kwargs)

    def elapsed_ms(self, started_at: float) -> int:
        _ = started_at
        return 1


def rex_action(
    action: str,
    payload: dict,
    *,
    explicit: bool = False,
    auto: bool = False,
) -> str:
    body: dict = {"action": action, "payload": payload}
    if explicit:
        body["explicit"] = True
    if auto:
        body["auto"] = True
    return "```rex_action\n" + json.dumps(body) + "\n```"


def tool_call(
    action: str,
    payload: dict | None = None,
    *,
    explicit: bool = False,
    auto: bool = False,
    arguments: str | None = None,
) -> dict:
    """One rex_action tool call in the shape the API returns it."""
    body: dict = {"action": action}
    if payload is not None:
        body["payload"] = payload
    if explicit:
        body["explicit"] = True
    if auto:
        body["auto"] = True
    return {
        "id": "call-1",
        "type": "function",
        "function": {
            "name": TOOL_NAME,
            "arguments": arguments if arguments is not None else json.dumps(body),
        },
    }


async def finalize_turn(
    rex_response: str,
    *,
    settings: AssistantProposalSettings,
    sources: tuple,
    user_text: str,
    brain: FakeGrokBrain | None = None,
    financial_context: dict | None = None,
    tool_calls: tuple | None = None,
    was_cut_off: bool = False,
) -> dict:
    runner = build_fetch_runner(
        sources=sources,
        grok_turn_brain=brain or FakeGrokBrain(),
        usage_recorder=FakeUsageRecorder(),
        channel=SimpleNamespace(value="chat"),
        max_tokens=1200,
    )
    return await finalize_grok_turn(
        rex_response,
        clarity_action_parser=ClarityActionParser(),
        truth_service=ChatResponseTruthService(),
        durable_write_service=DurableWriteService(memory_service=NoPendingStore()),
        proposal_settings=settings,
        brain_message=user_text,
        user_message={"id": "u1", "content": user_text},
        conversation_id="c1",
        conversation_history=[],
        turn_trace=None,
        ai_messages=[{"role": "system", "content": "tiny"}],
        financial_context=financial_context,
        fetch_runner=runner,
        tool_calls=tool_calls,
        was_cut_off=was_cut_off,
    )

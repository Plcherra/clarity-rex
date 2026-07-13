"""Phase 0: consecutive Off → Text → Card mode resolution and observability."""

from __future__ import annotations

import pytest

from app.services.assistant_proposal_settings import (
    AUTO_PROPOSALS_CARD,
    AUTO_PROPOSALS_OFF,
    AUTO_PROPOSALS_TEXT,
    ProposalSettingsResolution,
)
from app.services.chat_turn_observability import ChatTurnTrace
from app.services.chat_turn_orchestrator_support import annotate_proposal_settings
from app.services.open_thread_turn_service import (
    THREAD_OFFER_PHRASE,
    OpenThreadTurnService,
)
from app.services.open_thread_service import OpenThreadService
from app.services.assistant_proposal_settings import AssistantProposalSettings
from test_open_thread_service import FakeOpenThreadStore
from test_open_thread_turn_service import (
    FakeDurableWriteService,
    FakeTurnMemoryService,
)


class _FakeTurnContext:
    def __init__(self, resolution: ProposalSettingsResolution) -> None:
        self.proposal_settings = resolution.settings
        self.proposal_settings_resolution = resolution


@pytest.mark.asyncio
async def test_consecutive_turns_resolve_off_text_card_independently(monkeypatch):
    """Each turn must see the mode active for that turn (no conversation sticky)."""
    monkeypatch.delenv("REX_AUTO_PROPOSALS_MODE", raising=False)
    from app.config import get_settings

    get_settings.cache_clear()

    modes = [AUTO_PROPOSALS_OFF, AUTO_PROPOSALS_TEXT, AUTO_PROPOSALS_CARD]
    observed_effective: list[str] = []
    observed_handlers: list[str] = []

    habit = "I want to change my sleep schedule and wake up every day at 6am."
    memory = FakeTurnMemoryService()
    durable = FakeDurableWriteService()
    threads = OpenThreadService(FakeOpenThreadStore())
    service = OpenThreadTurnService(
        memory,
        open_thread_service=threads,
        durable_write_service=durable,
    )

    for mode in modes:
        settings = AssistantProposalSettings(mode=mode)
        resolution = ProposalSettingsResolution(
            settings=settings,
            profile_mode=mode,
            env_mode=None,
            settings_load_status="ok",
        )
        turn_trace = ChatTurnTrace(conversation_id="conv-mode", intent="unknown")
        annotate_proposal_settings(turn_trace, _FakeTurnContext(resolution))
        observed_effective.append(turn_trace.effective_mode or "")

        result = await service.handle_turn(
            habit,
            conversation_id="conv-mode",
            user_message={"id": f"user-{mode}", "content": habit},
            conversation_history=[],
            proposal_settings=settings,
        )
        if mode == AUTO_PROPOSALS_OFF:
            assert result is None
            observed_handlers.append("none")
        elif mode == AUTO_PROPOSALS_TEXT:
            assert result is not None
            assert THREAD_OFFER_PHRASE in result["response"]
            assert not (result.get("memory_changes") or {}).get("write_proposals")
            observed_handlers.append("open_thread_text")
        else:
            assert result is not None
            proposals = (result.get("memory_changes") or {}).get("write_proposals") or []
            assert proposals
            assert proposals[0]["write_kind"] == "open_thread"
            observed_handlers.append("open_thread_card")

    assert observed_effective == modes
    assert observed_handlers == ["none", "open_thread_text", "open_thread_card"]
    get_settings.cache_clear()

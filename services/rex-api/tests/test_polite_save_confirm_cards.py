"""Polite save phrasing must short-circuit into confirm cards."""

from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.goal_command_detection import GoalCommandDetector
from app.services.rex_intent_router import RexIntent, RexIntentRouter
from app.services.time_context_service import TimeContextService
from chat_service_fakes import FakeAIService, FakeMemoryService


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


def test_goal_detector_handles_save_a_plan_to():
    detector = GoalCommandDetector()
    commands = detector.detect_commands(
        "can you save a plan to pay my bills tomorrow?",
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )
    assert len(commands) == 1
    assert "pay my bills tomorrow" in commands[0].body.casefold()


def test_goal_detector_handles_remember_me_to():
    detector = GoalCommandDetector()
    commands = detector.detect_commands(
        "can you remember me to pay cursor tomorrow?",
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )
    # Remind-me phrases are Open Thread territory, not Goals short-circuit.
    assert commands == []


@pytest.mark.asyncio
async def test_polite_remember_me_returns_open_thread_or_confirm(monkeypatch):
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "card")
    from app.config import get_settings

    get_settings.cache_clear()
    chat_service = ChatService(
        FakeAIService(response="Yes, I'll save that as a Goal."),
        FileService(),
        FakeMemoryService(),
        time_context_service=_fixed_time_context_service(),
    )
    proposed = await chat_service.send_message(
        "can you remember me to pay cursor tomorrow?"
    )
    changes = proposed.get("memory_changes") or {}
    # Must not fake-save; either a confirm card or honest non-success copy.
    assert "yes, i'll save" not in proposed["response"].casefold()
    assert "yes, saved" not in proposed["response"].casefold()
    if changes.get("confirmation_required"):
        assert changes.get("write_proposals")
    get_settings.cache_clear()


def test_intent_router_marks_polite_friend_save_as_memory_save():
    decision = RexIntentRouter().classify("can you save sabrina as my friend?")
    assert decision.intent == RexIntent.MEMORY_SAVE


@pytest.mark.asyncio
async def test_polite_friend_save_returns_confirm_card(monkeypatch):
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "card")
    from app.config import get_settings

    get_settings.cache_clear()
    chat_service = ChatService(
        FakeAIService(response="Yes, saved: Sabrina is my friend."),
        FileService(),
        FakeMemoryService(),
        time_context_service=_fixed_time_context_service(),
    )
    proposed = await chat_service.send_message("can you save sabrina as my friend?")
    changes = proposed["memory_changes"]
    assert changes["confirmation_required"] == 1
    assert changes.get("write_proposals")
    assert "yes, saved" not in proposed["response"].casefold()
    get_settings.cache_clear()


@pytest.mark.asyncio
async def test_polite_plan_save_returns_confirm_card(monkeypatch):
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "card")
    from app.config import get_settings

    get_settings.cache_clear()
    chat_service = ChatService(
        FakeAIService(response="Yes, I'll save that as a Goal."),
        FileService(),
        FakeMemoryService(),
        time_context_service=_fixed_time_context_service(),
    )
    proposed = await chat_service.send_message(
        "can you save a plan to pay my bills tomorrow?"
    )
    changes = proposed["memory_changes"]
    assert changes["confirmation_required"] == 1
    assert changes.get("write_proposals")
    get_settings.cache_clear()

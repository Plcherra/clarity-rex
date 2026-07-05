from __future__ import annotations

import pytest

from app.models.open_thread import OpenThreadCreateRequest, MAX_ACTIVE_OPEN_THREADS
from app.services.open_thread_eligibility import (
    infer_thread_title,
    is_clear_measurable_goal,
    is_explicit_track_consent,
    is_recall_message,
    should_propose_open_thread_confirm_card,
    thread_offer_eligible,
    thread_offer_message_eligible,
)
from app.services.open_thread_service import OpenThreadService, OpenThreadServiceError
from app.services.prompt_open_threads_context import format_open_threads_context


class FakeOpenThreadStore:
    def __init__(self, user_id: str = "user-1") -> None:
        self.user_id = user_id
        self.rows: list[dict] = []

    async def _create_record(self, table: str, body: dict, select: str) -> dict:
        row = {
            "id": f"thread-{len(self.rows) + 1}",
            **body,
            "created_at": "2026-07-03T00:00:00Z",
            "updated_at": "2026-07-03T00:00:00Z",
        }
        self.rows.append(row)
        return row

    async def _list_records(
        self,
        table: str,
        *,
        select: str,
        filters: dict,
        order: str,
        limit: int,
        offset: int = 0,
    ) -> list[dict]:
        rows = list(self.rows)
        status = filters.get("status")
        if status is not None:
            rows = [row for row in rows if row.get("status") == status]
        thread_id = filters.get("id")
        if thread_id is not None:
            rows = [row for row in rows if row.get("id") == thread_id]
        return rows[:limit]

    async def _update_record(
        self,
        table: str,
        record_id: str,
        *,
        updates: dict,
        select: str,
        empty_detail: str,
    ) -> dict | None:
        for row in self.rows:
            if row.get("id") == record_id:
                row.update(updates)
                row["updated_at"] = "2026-07-03T01:00:00Z"
                return row
        return None


@pytest.mark.asyncio
async def test_create_open_thread_respects_active_cap() -> None:
    store = FakeOpenThreadStore()
    service = OpenThreadService(store)
    for index in range(MAX_ACTIVE_OPEN_THREADS):
        await service.create_thread(
            OpenThreadCreateRequest(title=f"Thread {index}", summary="ongoing topic")
        )

    with pytest.raises(OpenThreadServiceError) as error:
        await service.create_thread(
            OpenThreadCreateRequest(title="One too many", summary="should fail")
        )
    assert error.value.status_code == 409


def test_thread_offer_eligible_uses_generic_signals() -> None:
    assert thread_offer_eligible(
        "I've been trying to figure out a better morning routine lately.",
        already_offered=False,
        already_declined=False,
        active_thread_count=0,
    )
    assert not thread_offer_eligible(
        "hey",
        already_offered=False,
        already_declined=False,
        active_thread_count=0,
    )
    assert not thread_offer_eligible(
        "About changing my night routine right now.",
        already_offered=False,
        already_declined=False,
        active_thread_count=0,
    )
    assert not thread_offer_eligible(
        "Hey. I just got an idea.",
        already_offered=False,
        already_declined=False,
        active_thread_count=0,
    )
    assert is_recall_message("Do you remember what I said about training?")
    assert is_explicit_track_consent("Yes, keep track of this please")


@pytest.mark.parametrize(
    "message",
    [
        "I'm changing my night routine — no screens after 9, reading before bed to fix sleep.",
        "I want to build an app in my evenings and keep working on it.",
        "I'm working on my citizenship application and it has been really stressful lately.",
    ],
)
def test_thread_offer_eligible_accepts_actionable_continuity(message: str) -> None:
    assert thread_offer_eligible(
        message,
        already_offered=False,
        already_declined=False,
        active_thread_count=0,
    )


@pytest.mark.parametrize(
    "message",
    [
        "The citizenship process is overwhelming and has been really stressful lately.",
        "Money has been really tight lately and it is stressful to keep up.",
        "We're moving next month and it is stressful figuring out logistics.",
    ],
)
def test_thread_offer_eligible_rejects_vague_or_stress_only_messages(message: str) -> None:
    assert not thread_offer_eligible(
        message,
        already_offered=False,
        already_declined=False,
        active_thread_count=0,
    )


def test_thread_offer_eligible_accepts_multi_turn_elaboration() -> None:
    history = [
        {"role": "user", "content": "Hey. I just got an idea."},
        {"role": "assistant", "content": "What's the idea?"},
        {"role": "user", "content": "About changing my night routine right now."},
        {
            "role": "user",
            "content": (
                "Yeah. It's just because I'm having some problem to sleep, "
                "so now I got a plan."
            ),
        },
    ]
    assert thread_offer_eligible(
        history[-1]["content"],
        already_offered=False,
        already_declined=False,
        active_thread_count=0,
        conversation_history=history,
    )


def test_thread_offer_eligible_defers_clear_measurable_goals() -> None:
    assert not thread_offer_eligible(
        "I need to save $5000 by December for my emergency fund.",
        already_offered=False,
        already_declined=False,
        active_thread_count=0,
    )
    assert is_clear_measurable_goal("My goal is to save enough for a down payment.")


def test_prompt_labels_open_threads_as_not_saved_memory() -> None:
    rendered = format_open_threads_context(
        [
            {
                "status": "active",
                "title": "Morning routine",
                "summary": "Trying to wake up earlier",
            }
        ]
    )
    assert rendered is not None
    assert "not saved memory" in rendered.lower()
    assert "Morning routine" in rendered


def test_infer_thread_title_truncates_long_messages() -> None:
    message = " ".join(["word"] * 30)
    title = infer_thread_title(message, max_length=40)
    assert len(title) <= 40
    assert title != message


def test_should_propose_open_thread_confirm_card_for_clear_plans_only() -> None:
    assert should_propose_open_thread_confirm_card(
        "I've been trying to figure out a better morning routine lately.",
    )
    assert should_propose_open_thread_confirm_card(
        "I'm changing my night routine — no screens after 9, reading before bed to fix sleep.",
    )
    assert not should_propose_open_thread_confirm_card(
        "I'm working on my citizenship application and it has been really stressful lately.",
    )


def test_thread_offer_message_eligible_ignores_cap_signal():
    message = "I've been trying to figure out a better morning routine lately."
    assert thread_offer_message_eligible(
        message,
        already_offered=False,
        already_declined=False,
    )
    assert not thread_offer_eligible(
        message,
        already_offered=False,
        already_declined=False,
        active_thread_count=MAX_ACTIVE_OPEN_THREADS,
    )

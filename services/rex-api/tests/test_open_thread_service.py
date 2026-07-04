from __future__ import annotations

import pytest

from app.models.open_thread import OpenThreadCreateRequest, MAX_ACTIVE_OPEN_THREADS
from app.services.open_thread_eligibility import (
    infer_thread_title,
    is_explicit_track_consent,
    is_recall_message,
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
    assert is_recall_message("Do you remember what I said about training?")
    assert is_explicit_track_consent("Yes, keep track of this please")


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

"""Fakes for Phase G recall turns (search_chats / list_knows_summary)."""

from __future__ import annotations

from typing import Optional

from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.capabilities.recall_capability import build_recall_fetch_source
from app.services.memory_context_status import (
    CONTEXT_ERROR_KEY,
    CONTEXT_STATUS_KEY,
)
from turn_fetch_fakes import FakeGrokBrain, finalize_turn, rex_action

__all__ = [
    "FakeGrokBrain",
    "FakeOverviewService",
    "FakeRecallService",
    "chat_excerpt",
    "empty_overview",
    "finalize_recall_turn",
    "rex_action",
    "search_status",
]


def search_status(**overrides) -> dict:
    """The status row `fetch_relevant_chat_excerpts` puts first in its list."""
    status = {
        CONTEXT_STATUS_KEY: True,
        "source": "chat_search",
        "attempted": True,
        "succeeded": True,
        "result_count": 1,
        "raw_match_count": 1,
        "filtered_match_count": 0,
        "filtered_all_matches": False,
        "scanned_messages": 40,
        "partial": False,
        "full_scan_used": False,
        "query_modes": ["keyword"],
        "queries": [],
        "failures": [],
        "status": "found",
    }
    status.update(overrides)
    return status


def chat_excerpt(content: str, *, conversation_id: str = "conv-old") -> dict:
    return {
        "id": f"chat-{conversation_id}",
        "content": content,
        "conversation_id": conversation_id,
        "relevance_score": 4.0,
    }


class FakeRecallService:
    def __init__(self, items: Optional[list[dict]] = None, *, raises: bool = False):
        self.items = items if items is not None else [search_status()]
        self.raises = raises
        self.calls: list[dict] = []

    async def fetch_relevant_chat_excerpts(self, **kwargs) -> list[dict]:
        self.calls.append(kwargs)
        if self.raises:
            raise RuntimeError("search backend down")
        return list(self.items)

    @classmethod
    def with_hits(cls, *contents: str) -> "FakeRecallService":
        return cls(
            [
                search_status(result_count=len(contents), raw_match_count=len(contents)),
                *[chat_excerpt(content) for content in contents],
            ]
        )

    @classmethod
    def empty(cls) -> "FakeRecallService":
        return cls([search_status(status="empty", result_count=0, raw_match_count=0)])

    @classmethod
    def broken(cls) -> "FakeRecallService":
        return cls(
            [
                {
                    CONTEXT_ERROR_KEY: True,
                    "source": "chat_search",
                    "message": "Past chat search is unavailable.",
                }
            ]
        )


def empty_overview() -> dict:
    return {
        "people": [],
        "places": [],
        "other_entities": [],
        "facts": [],
        "rules": [],
        "plans": [],
        "counts": {"total": 0},
    }


class FakeOverviewService:
    def __init__(self, overview: Optional[dict] = None, *, raises: bool = False):
        self.overview = overview if overview is not None else empty_overview()
        self.raises = raises
        self.calls = 0

    async def get_overview(self, **kwargs) -> dict:
        _ = kwargs
        self.calls += 1
        if self.raises:
            raise RuntimeError("knows read failed")
        return self.overview


async def finalize_recall_turn(
    rex_response: str,
    *,
    settings: AssistantProposalSettings,
    recall_service: Optional[FakeRecallService] = None,
    overview_service: Optional[FakeOverviewService] = None,
    user_text: str = "Did we ever talk about the motorcycle?",
    brain: Optional[FakeGrokBrain] = None,
) -> dict:
    return await finalize_turn(
        rex_response,
        settings=settings,
        sources=(
            build_recall_fetch_source(
                recall_service=recall_service or FakeRecallService.empty(),
                overview_service=overview_service or FakeOverviewService(),
                conversation_id="c1",
                user_message=user_text,
            ),
        ),
        user_text=user_text,
        brain=brain,
    )

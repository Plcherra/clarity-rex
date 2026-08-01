"""Parse recall fetch payloads from Grok actions (plan 05 Phase G)."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, Optional

from app.services.brain_action_schema import BrainAction

SEARCH_CHATS = "search_chats"
LIST_KNOWS_SUMMARY = "list_knows_summary"
RECALL_FETCH_ACTIONS = frozenset({SEARCH_CHATS, LIST_KNOWS_SUMMARY})


@dataclass(frozen=True)
class RecallFetchRequest:
    name: str
    query: str = ""

    @property
    def is_inventory(self) -> bool:
        return self.name == LIST_KNOWS_SUMMARY


def is_recall_fetch_action(action: BrainAction) -> bool:
    return action.name in RECALL_FETCH_ACTIONS


def recall_fetch_request(
    action: BrainAction,
    *,
    user_message: str = "",
) -> Optional[RecallFetchRequest]:
    """A search needs terms; fall back to what the user said when Grok omits them.

    Grok sometimes emits `search_chats` with no payload because the question is
    right there in the turn. Falling back beats refusing over a missing field.
    """
    if not is_recall_fetch_action(action):
        return None
    payload = action.payload if isinstance(action.payload, dict) else {}
    query = _first_text(
        payload.get("query"),
        payload.get("topic"),
        payload.get("q"),
        payload.get("search"),
        payload.get("terms"),
        payload.get("content"),
    )
    if not query and action.name == SEARCH_CHATS:
        query = str(user_message or "").strip()
    return RecallFetchRequest(name=action.name, query=query)


def recall_fetch_requests(
    actions: Iterable[BrainAction],
    *,
    user_message: str = "",
) -> list[RecallFetchRequest]:
    """One request per capability — a repeated name is the same read twice."""
    requests: list[RecallFetchRequest] = []
    seen: set[str] = set()
    for action in actions:
        request = recall_fetch_request(action, user_message=user_message)
        if request is None or request.name in seen:
            continue
        seen.add(request.name)
        requests.append(request)
    return requests


def _first_text(*values: object) -> str:
    for value in values:
        text = str(value or "").strip()
        if text:
            return text
    return ""

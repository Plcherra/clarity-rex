"""Handle open thread consent, decline, and confirm-card proposals."""

from __future__ import annotations

from typing import Any, Optional

from app.models.open_thread import MAX_ACTIVE_OPEN_THREADS
from app.services.conversation_pending_action import PendingAction
from app.services.goal_command_results import clarification_turn_result
from app.services.open_thread_eligibility import (
    infer_thread_title,
    is_bare_pending_offer_decline,
    is_explicit_track_consent,
    is_explicit_track_decline,
    thread_offer_eligible,
    thread_offer_message_eligible,
    thread_summary_from_message,
)


THREAD_OFFER_PHRASE = "Want me to keep track of this and check in later?"
THREAD_OFFER_DETAIL = (
    "It would show up in your Goals tab as an open thread — not saved memory."
)


class OpenThreadTurnService:
    def __init__(
        self,
        memory_service: Any,
        *,
        open_thread_service: Any = None,
        durable_write_service: Any = None,
    ) -> None:
        self.memory_service = memory_service
        self.open_thread_service = open_thread_service
        self.durable_write_service = durable_write_service

    async def handle_turn(
        self,
        message: str,
        *,
        conversation_id: str,
        user_message: dict,
        conversation_history: list[dict],
        pending_action: Any = None,
    ) -> Optional[dict]:
        if pending_action is not None:
            pending = (
                pending_action
                if isinstance(pending_action, PendingAction)
                else PendingAction.from_dict(pending_action)
            )
            if pending is not None and pending.action_type == "durable_write":
                return None

        if self.open_thread_service is None or self.durable_write_service is None:
            return None

        offer_state = self._offer_state_from_history(conversation_history)
        active_threads = await self.open_thread_service.list_active_threads()
        offer_context = await self._load_offer_context()

        if is_explicit_track_decline(message) or (
            offer_state.get("offered")
            and not offer_state.get("declined")
            and is_bare_pending_offer_decline(message)
        ):
            return await clarification_turn_result(
                self.memory_service,
                conversation_id=conversation_id,
                user_message=user_message,
                response="Okay, I won't track that as an open thread.",
            )

        if is_explicit_track_consent(message) or self._recent_offer_pending(
            offer_state,
            message,
        ):
            topic_message = offer_state.get("topic_message") or message
            title = infer_thread_title(
                topic_message,
                conversation_history=conversation_history,
            )
            summary = thread_summary_from_message(
                topic_message,
                conversation_history=conversation_history,
            )
            return await self.durable_write_service.propose_open_thread(
                title=title,
                summary=summary,
                conversation_id=conversation_id,
                user_message=user_message,
            )

        if offer_state.get("offered") or offer_state.get("declined"):
            return None

        if (
            len(active_threads) >= MAX_ACTIVE_OPEN_THREADS
            and thread_offer_message_eligible(
                message,
                already_offered=bool(offer_state.get("offered")),
                already_declined=bool(offer_state.get("declined")),
                conversation_history=conversation_history,
                **offer_context,
            )
        ):
            replace_candidate = await self.open_thread_service.least_recently_used_active()
            candidate_title = (
                str(replace_candidate.get("title") or "").strip()
                if replace_candidate
                else ""
            )
            replace_hint = (
                f' Maybe close or pause "{candidate_title}" first?'
                if candidate_title
                else " Close or pause one in Goals first?"
            )
            return await clarification_turn_result(
                self.memory_service,
                conversation_id=conversation_id,
                user_message=user_message,
                response=(
                    "You already have 5 active open threads, so I can't add another "
                    "companion follow-up right now."
                    f"{replace_hint} Open threads live in Goals — not saved memory."
                ),
            )

        if not thread_offer_eligible(
            message,
            already_offered=bool(offer_state.get("offered")),
            already_declined=bool(offer_state.get("declined")),
            active_thread_count=len(active_threads),
            max_active=MAX_ACTIVE_OPEN_THREADS,
            conversation_history=conversation_history,
            active_threads=active_threads,
            **offer_context,
        ):
            return None

        return await clarification_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=f"{THREAD_OFFER_PHRASE} {THREAD_OFFER_DETAIL}",
        )

    def _recent_offer_pending(self, offer_state: dict, message: str) -> bool:
        if not offer_state.get("offered") or offer_state.get("declined"):
            return False
        normalized = message.strip().casefold()
        return normalized in {"yes", "yeah", "yep", "sure", "ok", "okay", "please"}

    def _offer_state_from_history(self, conversation_history: list[dict]) -> dict:
        offered = False
        declined = False
        topic_message = ""
        offer_index = -1

        for index, entry in enumerate(conversation_history):
            role = str(entry.get("role") or "")
            content = str(entry.get("content") or "")
            if role == "assistant" and THREAD_OFFER_PHRASE in content:
                offered = True
                offer_index = index
                for previous in reversed(conversation_history[:index]):
                    if str(previous.get("role") or "") != "user":
                        continue
                    candidate = str(previous.get("content") or "").strip()
                    if has_substantive_user_content(candidate):
                        topic_message = candidate
                        break
                break

        if offered and offer_index >= 0:
            for entry in conversation_history[offer_index + 1 :]:
                if str(entry.get("role") or "") != "user":
                    continue
                content = str(entry.get("content") or "")
                if is_explicit_track_decline(content) or is_bare_pending_offer_decline(
                    content,
                ):
                    declined = True
                    break
                if is_explicit_track_consent(content):
                    break

        return {
            "offered": offered,
            "declined": declined,
            "topic_message": topic_message,
        }

    async def _load_offer_context(self) -> dict[str, list[dict]]:
        active_plans: list[dict] = []
        saved_memories: list[dict] = []
        active_entities: list[dict] = []

        list_plans = getattr(self.memory_service, "list_plans", None)
        if list_plans is not None:
            try:
                active_plans = await list_plans(active=True, limit=20)
            except TypeError:
                active_plans = await list_plans(limit=20)

        list_memory = getattr(self.memory_service, "list_long_term_memory", None)
        if list_memory is not None:
            try:
                saved_memories = await list_memory(active=True, limit=30)
            except TypeError:
                saved_memories = await list_memory(limit=30)

        list_entities = getattr(self.memory_service, "list_entities", None)
        if list_entities is not None:
            try:
                active_entities = await list_entities(active=True, limit=30)
            except TypeError:
                active_entities = await list_entities(limit=30)

        return {
            "active_plans": active_plans,
            "saved_memories": saved_memories,
            "active_entities": active_entities,
        }


def has_substantive_user_content(content: str) -> bool:
    cleaned = content.strip()
    if len(cleaned) < 20:
        return False
    if cleaned.casefold() in {"yes", "no", "ok", "okay", "thanks"}:
        return False
    return True

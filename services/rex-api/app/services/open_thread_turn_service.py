"""Handle open thread consent, decline, and confirm-card proposals."""

from __future__ import annotations

from typing import Any, Optional

from app.models.open_thread import MAX_ACTIVE_OPEN_THREADS
from app.services.conversation_pending_action import PendingAction
from app.services.goal_command_results import clarification_turn_result
from app.services.open_thread_eligibility import (
    infer_thread_title,
    is_explicit_track_consent,
    is_explicit_track_decline,
    thread_offer_eligible,
    thread_summary_from_message,
)


THREAD_OFFER_PHRASE = "Want me to keep track of this and check in later?"


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

        if is_explicit_track_decline(message):
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
            title = infer_thread_title(
                offer_state.get("topic_message") or message,
            )
            summary = thread_summary_from_message(
                offer_state.get("topic_message") or message,
            )
            return await self.durable_write_service.propose_open_thread(
                title=title,
                summary=summary,
                conversation_id=conversation_id,
                user_message=user_message,
            )

        if offer_state.get("offered") or offer_state.get("declined"):
            return None

        if not thread_offer_eligible(
            message,
            already_offered=bool(offer_state.get("offered")),
            already_declined=bool(offer_state.get("declined")),
            active_thread_count=len(active_threads),
            max_active=MAX_ACTIVE_OPEN_THREADS,
        ):
            return None

        return await clarification_turn_result(
            self.memory_service,
            conversation_id=conversation_id,
            user_message=user_message,
            response=(
                f"{THREAD_OFFER_PHRASE} "
                "It would show up in your Goals tab as an open thread — "
                "not saved memory."
            ),
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
                if is_explicit_track_decline(content):
                    declined = True
                    break
                if is_explicit_track_consent(content):
                    break

        return {
            "offered": offered,
            "declined": declined,
            "topic_message": topic_message,
        }


def has_substantive_user_content(content: str) -> bool:
    cleaned = content.strip()
    if len(cleaned) < 20:
        return False
    if cleaned.casefold() in {"yes", "no", "ok", "okay", "thanks"}:
        return False
    return True

"""Detail matching and scoring helpers for chat recall excerpts."""

from __future__ import annotations

import re

from app.services.chat_recall_filters import (
    is_chat_search_no_result_message,
    is_chat_search_user_content_message,
    is_memory_rejection_message,
)

CHAT_RELATED_DETAIL_CONTEXT_RADIUS = 24
CHAT_RELATED_DETAIL_MARKERS = (
    "amount",
    "birthday",
    "by ",
    "deadline",
    "for ",
    "june",
    "model",
    "pay",
    "send",
    "sent",
    "transfer",
)


class ChatRecallExcerptDetailMixin:
    def with_related_detail_messages(
        self,
        context_messages: list[dict],
        *,
        conversation_messages: list[dict],
        matched_messages: list[dict],
        matched_indexes: list[int],
    ) -> list[dict]:
        if not context_messages or not matched_indexes:
            return context_messages

        selected_ids = {
            str(message.get("id") or "")
            for message in context_messages
            if str(message.get("id") or "")
        }
        matched_terms = self.matched_terms(matched_messages)
        selected = list(context_messages)
        for index, message in enumerate(conversation_messages):
            message_id = str(message.get("id") or "")
            if message_id and message_id in selected_ids:
                continue
            if not self.is_near_match(index, matched_indexes):
                continue
            if not is_chat_search_user_content_message(message):
                continue
            if self.message_was_rejected_in_conversation(
                index,
                conversation_messages,
            ):
                continue
            if not (
                self.message_contains_term(message, matched_terms)
                or self.message_has_detail_marker(message)
            ):
                continue
            if message_id:
                selected_ids.add(message_id)
            selected.append(message)

        order = {
            str(message.get("id") or ""): index
            for index, message in enumerate(conversation_messages)
            if str(message.get("id") or "")
        }
        return sorted(
            selected,
            key=lambda message: order.get(str(message.get("id") or ""), 10_000),
        )

    def matched_terms(self, matched_messages: list[dict]) -> set[str]:
        terms = {
            str(term).lower()
            for message in matched_messages
            for term in message.get("_chat_search_matched_terms", [])
            if str(term).strip()
        }
        return {term for term in terms if len(term) >= 2}

    def is_near_match(self, index: int, matched_indexes: list[int]) -> bool:
        return any(
            abs(index - matched_index) <= CHAT_RELATED_DETAIL_CONTEXT_RADIUS
            for matched_index in matched_indexes
        )

    def message_contains_term(self, message: dict, terms: set[str]) -> bool:
        if not terms:
            return False
        content = str(message.get("content") or "").lower()
        return any(term in content for term in terms)

    def message_has_detail_marker(self, message: dict) -> bool:
        content = str(message.get("content") or "").lower()
        if not content:
            return False
        if self.text_has_amount(content):
            return True
        return any(marker in content for marker in CHAT_RELATED_DETAIL_MARKERS)

    def group_detail_score(self, messages: list[dict]) -> int:
        return sum(
            1
            for message in messages
            if is_chat_search_user_content_message(message)
            and self.message_has_detail_marker(message)
        )

    def group_inventory_score(self, messages: list[dict]) -> int:
        return sum(
            1 for message in messages if self.message_has_inventory_detail(message)
        )

    def message_has_inventory_detail(self, message: dict) -> bool:
        content = str(message.get("content") or "").lower()
        if not content:
            return False
        if re.search(
            r"\b(?:bought|purchased|downloaded|grabbed|picked up|added|"
            r"preordered|snagged|gog|steam|epic games)\b",
            content,
        ):
            return True
        if str(message.get("role") or "") == "assistant" and re.search(
            r"\b(?:solid picks|nice haul|you (?:got|have|bought))\b",
            content,
        ):
            return True
        return False

    def group_factual_count(self, messages: list[dict]) -> int:
        return sum(
            1 for message in messages if is_chat_search_user_content_message(message)
        )

    def group_noise_count(self, messages: list[dict]) -> int:
        return sum(
            1
            for message in messages
            if is_chat_search_no_result_message(message)
            or not is_chat_search_user_content_message(message)
        )

    def text_has_amount(self, text: str) -> bool:
        if re.search(r"\$\s*\d|\b\d+(?:\.\d{2})?\s*(?:bucks|dollars)\b", text):
            return True
        if re.search(
            r"\b\d+\b.{0,40}\b(?:money|cash|send|sent|sending|transfer|gift)\b",
            text,
        ):
            return True
        if re.search(
            r"\b(?:money|cash|send|sent|sending|transfer|gift)\b.{0,40}\b\d+\b",
            text,
        ):
            return True
        return False

    def message_was_rejected_in_conversation(
        self,
        message_index: int,
        conversation_messages: list[dict],
    ) -> bool:
        following_messages = conversation_messages[
            message_index + 1 : message_index + 7
        ]
        return any(
            str(item.get("role") or "") == "user"
            and is_memory_rejection_message(item)
            for item in following_messages
        )

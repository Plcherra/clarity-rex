import re
from typing import Optional

from app.services.chat_search_terms import ChatSearchTermBuilder


PROFILE_MEMORY_QUERY = (
    "user profile identity facts preferences saved knowledge personal details"
)
MEMORY_INVENTORY_QUERY = (
    f"{PROFILE_MEMORY_QUERY} people relationships plans goals commitments "
    "personal rules memories chats conversations"
)
PROFILE_MEMORY_LIMIT = 4
RECALL_TRIGGER_PHRASES = (
    "chat history",
    "conversation history",
    "dig up",
    "look back",
    "old chat",
    "old chats",
    "past chat",
    "past chats",
    "previous chat",
    "previous chats",
    "pull up",
)
RECALL_FOLLOWUP_TERMS = (
    "by when",
    "for what",
    "that",
    "there",
    "it",
    "her",
    "him",
    "them",
    "this",
    "details",
    "mention",
    "mentioned",
    "the chat",
    "old chat",
    "old chats",
    "how much",
    "what amount",
    "what date",
    "what else",
    "why",
)
ROUTER_RECALL_QUESTION_TERMS = (
    "anything about me",
    "do you know anything",
    "do you know my",
    "do you know where",
    "do you remember",
    "what information do you have",
    "what information",
    "what do you remember",
    "what do you know",
    "what are my plans",
    "what city",
    "what rex knows",
    "what is my",
    "where i am",
    "where i'm",
    "where i'm located",
    "where do i live",
    "where am i",
)
ROUTER_RECALL_ACTION_TERMS = (
    "chat",
    "chats",
    "conversation",
    "conversations",
    "do you have",
    "do you know",
    "do you remember",
    "have i told you",
    "have we talked",
    "remember",
    "search",
    "talked about",
    "tell me what",
    "what did i tell you",
    "what do you have",
    "what do you know",
    "what do you remember",
    "what have i told you",
    "what have we talked",
    "what information",
)
USER_SCOPED_RECALL_TERMS = (
    " about me",
    " about my ",
    " i ",
    " i'm ",
    " me ",
    " my ",
    " our ",
    " us ",
    " we ",
)
FINANCE_ONLY_TERMS = (
    "account",
    "accounts",
    "balance",
    "balances",
    "bank",
    "budget",
    "budgets",
    "merchant",
    "merchants",
    "plaid",
    "spend",
    "spending",
    "spent",
    "transaction",
    "transactions",
)
CHAT_SCOPE_TERMS = (
    "chat",
    "chats",
    "conversation",
    "conversations",
    "history",
    "mentioned",
    "old",
    "past",
    "previous",
    "said",
    "talked",
    "told",
)


class RecallIntentHelper:
    def __init__(
        self,
        *,
        search_terms: Optional[ChatSearchTermBuilder] = None,
    ) -> None:
        self.search_terms = search_terms or ChatSearchTermBuilder()

    def memory_retrieval_query(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> str:
        normalized = self.normalized_recall_text(message)
        if self.is_memory_inventory_query(normalized):
            return MEMORY_INVENTORY_QUERY
        is_followup = self.is_contextual_memory_followup(
            normalized,
        ) or self.is_about_recall_followup(normalized)
        if is_followup:
            subject = self.recent_memory_subject(conversation_history)
            if subject:
                return f"{subject} {message}".strip()
        return message

    def recall_search_query(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> Optional[str]:
        if not self.is_recall_request(
            message,
            conversation_history=conversation_history,
        ):
            return None
        normalized = self.normalized_recall_text(message)
        is_followup = self.is_contextual_memory_followup(
            normalized,
        ) or self.is_about_recall_followup(normalized)
        if is_followup:
            subject = self.recent_memory_subject(conversation_history)
            if subject:
                return self.chat_topic_query(f"{subject} {message}") or subject
        return self.chat_topic_query(message) or message

    def is_recall_request(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> bool:
        return self.should_force_chat_recall_search(
            message,
            conversation_history=conversation_history,
        )

    def is_router_memory_recall_request(self, message: str) -> bool:
        normalized = self.normalized_recall_text(message)
        if self.is_recall_request(normalized, conversation_history=[]):
            return True
        if any(term in normalized for term in ROUTER_RECALL_QUESTION_TERMS):
            return True
        if not any(term in normalized for term in ROUTER_RECALL_ACTION_TERMS):
            return False

        padded = f" {normalized} "
        return (
            any(term in padded for term in USER_SCOPED_RECALL_TERMS)
            or "anything" in normalized
            or "information" in normalized
            or "chat" in normalized
            or "conversation" in normalized
            or "what do you know" in normalized
            or "what do you remember" in normalized
        )

    def has_recall_topic_language(self, message: str) -> bool:
        normalized = self.normalized_recall_text(message)
        return self.should_force_chat_recall_search(
            normalized,
            conversation_history=[],
        )

    def is_memory_inventory_query(self, normalized_message: str) -> bool:
        broad_inventory_questions = {
            "what do you know",
            "what do you know about me",
            "what do you remember",
            "what do you remember about me",
            "what does clarity know",
            "what does clarity know about me",
            "what information do you have",
            "what information do you have about me",
            "what have you saved",
            "what do you have saved",
            "what do you have saved about me",
            "what rex knows",
            "what does rex know",
            "what does rex know about me",
            "what does rex remember",
            "what does rex remember about me",
            "what does hackrex know",
            "what does hackrex know about me",
            "what information do you know",
            "what information do you know about me",
        }
        normalized = normalized_message.rstrip("?.! ")
        if normalized not in broad_inventory_questions:
            return False
        return " about " not in f" {normalized} " or normalized.endswith(" about me")

    def is_contextual_memory_followup(self, normalized_message: str) -> bool:
        normalized_message = self.normalized_recall_text(normalized_message)
        stripped = normalized_message.strip("?.! ")
        if stripped in {
            "chat",
            "chats",
            "the chat",
            "the chats",
            "conversation",
            "conversations",
            "the conversation",
            "the conversations",
        }:
            return True
        return any(
            phrase in normalized_message
            for phrase in (
                "check old chat",
                "check old chats",
                "check chat",
                "check chats",
                "check the chat",
                "check the chats",
                "look into chat",
                "look into chats",
                "look into the chat",
                "look into the chats",
                "old chat",
                "old chats",
                "old conversation",
                "old conversations",
                "anything else",
                "what else",
                "about that",
                "past chat",
                "past chats",
                "past conversation",
                "past conversations",
                "previous chat",
                "previous chats",
                "previous conversation",
                "previous conversations",
                "search chat",
                "search chats",
                "search your chat",
                "search your chats",
                "search conversations",
            )
        )

    def should_force_chat_recall_search(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> bool:
        normalized = self.normalized_recall_text(message)
        stripped = normalized.strip("?.! ")
        if not stripped:
            return False
        if self.is_finance_only_request(normalized):
            return False
        if self.is_memory_inventory_query(normalized):
            return True
        if self.is_contextual_memory_followup(normalized):
            return True
        if self.is_subject_recall_question(normalized):
            return True
        if self.is_direct_recall_question(normalized):
            return True
        if self.is_search_recall_request(normalized):
            return True

        if any(phrase in normalized for phrase in RECALL_TRIGGER_PHRASES):
            return True
        has_question_language = re.search(
            r"\b(?:did|do|have|had|how|what|when|where|who|why)\b",
            normalized,
        )
        has_recall_verb = re.search(
            r"\b(?:mention|mentions|mentioned|say|said|tell|told|talk|talked|"
            r"discuss|discussed)\b",
            normalized,
        )
        if has_question_language and has_recall_verb:
            return True
        if has_question_language and self.has_user_scoped_past_reference(normalized):
            return True

        if conversation_history and any(
            term in normalized for term in RECALL_FOLLOWUP_TERMS
        ):
            return bool(self.recent_memory_subject(conversation_history))
        if conversation_history and self.is_about_recall_followup(normalized):
            return bool(self.recent_memory_subject(conversation_history))

        return False

    def is_finance_only_request(self, normalized_message: str) -> bool:
        if not any(term in normalized_message for term in FINANCE_ONLY_TERMS):
            return False
        return not any(term in normalized_message for term in CHAT_SCOPE_TERMS)

    def has_user_scoped_past_reference(self, normalized_message: str) -> bool:
        padded = f" {normalized_message} "
        if not any(term in padded for term in USER_SCOPED_RECALL_TERMS):
            return False
        return bool(
            re.search(
                r"\b(?:was|were|had|wanted|needed|planned|would|"
                r"going to|used to)\b",
                normalized_message,
            )
        )

    def is_subject_recall_question(self, normalized_message: str) -> bool:
        stripped = normalized_message.strip("?.! ")
        has_subject = re.search(
            r"\b(?:about|of|on|regarding|for|with)\s+[a-z0-9'\s]{2,80}",
            stripped,
        )
        if not has_subject:
            return False
        if re.match(
            r"^(?:anything|any info|any information)\s+"
            r"(?:about|of|on|regarding|for|with)\b",
            stripped,
        ):
            return True
        has_question_language = re.search(
            r"\b(?:what|which|do|does|did|have|has|can|could)\b",
            stripped,
        )
        has_recall_language = re.search(
            r"\b(?:know|remember|have|has|information|info|details|saved|"
            r"memory|memories|talked|said|mention|mentions|mentioned)\b",
            stripped,
        )
        return bool(has_question_language and has_recall_language)

    def is_direct_recall_question(self, normalized_message: str) -> bool:
        stripped = normalized_message.strip("?.! ")
        if not re.search(
            r"\b(?:did|do|have|had|how|what|when|where|who|why)\b",
            stripped,
        ):
            return False
        if re.search(
            r"\b(?:remember|recall|mention|mentions|mentioned|say|said|"
            r"tell|told|talk|talked|discuss|discussed)\b",
            stripped,
        ):
            return True
        if re.search(r"\b(?:know|have)\b", stripped):
            return bool(
                self.has_user_scoped_past_reference(stripped)
                or re.search(r"\b(?:about|of|regarding|on|for|with)\b", stripped)
            )
        return False

    def is_search_recall_request(self, normalized_message: str) -> bool:
        if not re.search(r"\bsearch(?:ing)?\b", normalized_message):
            return False
        if re.search(r"\b(?:web|internet|online|google|browser)\b", normalized_message):
            return False
        return True

    def chat_topic_query(self, message: str) -> str:
        return self.search_terms.assistant_topic_query(message)

    def normalized_recall_text(self, message: str) -> str:
        normalized = " ".join(str(message or "").lower().split())
        return re.sub(r"\bchet\b", "chat", normalized)

    def is_about_recall_followup(self, normalized_message: str) -> bool:
        stripped = self.normalized_recall_text(normalized_message).strip("?.! ")
        return re.fullmatch(r"about\s+[a-z0-9'\s]{2,80}", stripped) is not None

    def recent_memory_subject(self, conversation_history: list[dict]) -> str:
        for message in reversed(conversation_history[-8:]):
            if message.get("role") != "user":
                continue
            content = str(message.get("content") or "").strip()
            if not content:
                continue
            normalized = " ".join(content.lower().split())
            if self.is_contextual_memory_followup(normalized):
                continue
            if any(
                phrase in normalized
                for phrase in (
                    "do you know",
                    "do you remember",
                    "did i mention",
                    "did i say",
                    "find any mentions",
                    "find mentions",
                    "anything about",
                    "talking about",
                    "information about",
                    "what do you know about",
                    "what do you remember about",
                )
            ):
                return content
        return ""

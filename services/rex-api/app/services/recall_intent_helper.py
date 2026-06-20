import re
from typing import Optional


PROFILE_MEMORY_QUERY = (
    "user profile location timezone where I live state city home current time "
    "important identity facts birthdays family important dates preferences"
)
MEMORY_INVENTORY_QUERY = (
    f"{PROFILE_MEMORY_QUERY} people relationships parents mom mother dad father "
    "sibling friend birthday plans goals commitments personal rules memories "
    "chats conversations preferences"
)
PROFILE_MEMORY_LIMIT = 4
RECALL_TRIGGER_PHRASES = (
    "do you remember",
    "what do you remember",
    "remember when",
    "old chat",
    "old chats",
    "chat history",
    "past chat",
    "past chats",
    "previous chat",
    "previous chats",
    "search chat",
    "search chats",
    "search the chat",
    "find chat",
    "find chats",
    "find old chat",
    "find old chats",
    "search old",
    "check the chat",
    "check old",
    "look through chat",
    "talked about",
    "mentioned",
    "told you",
    "said before",
    "do you know about",
    "do you know anything about",
    "do you have any idea",
    "have any idea",
    "what do you know about",
    "anything about",
)
RECALL_FOLLOWUP_TERMS = (
    "that",
    "there",
    "it",
    "her",
    "him",
    "them",
    "this",
    "the chat",
    "old chat",
    "old chats",
)


class RecallIntentHelper:
    def memory_retrieval_query(
        self,
        message: str,
        *,
        conversation_history: list[dict],
    ) -> str:
        normalized = self.normalized_recall_text(message)
        if self.is_memory_inventory_query(normalized):
            return MEMORY_INVENTORY_QUERY
        if self.is_contextual_memory_followup(normalized):
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
        return self.memory_retrieval_query(
            message,
            conversation_history=conversation_history,
        )

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
        if self.is_memory_inventory_query(normalized):
            return True
        if self.is_contextual_memory_followup(normalized):
            return True

        if any(phrase in normalized for phrase in RECALL_TRIGGER_PHRASES):
            return True

        if re.search(
            r"\b(?:did|do|have|had)\s+(?:i|we)\b"
            r".*\b(?:mention|mentioned|say|said|tell|told|talk|talked|"
            r"discuss|discussed|play|played|buy|bought|send|sent)\b",
            normalized,
        ):
            return True
        if re.search(
            r"\bwhat\s+.+\b(?:did|do)\s+i\s+"
            r"(?:play|buy|want|mention|say|tell)",
            normalized,
        ):
            return True
        if re.search(
            r"\bwhat\s+did\s+i\s+"
            r"(?:play|buy|want|mention|say|tell|talk|discuss)\b",
            normalized,
        ):
            return True
        if re.search(
            r"\bwhat\s+(?:was|were)\b.*\b(?:i|we|my|our)\b",
            normalized,
        ):
            return True
        if re.search(
            r"\b(?:past|previous|earlier|before|history)\b",
            normalized,
        ):
            return True

        if conversation_history and any(
            term in normalized for term in RECALL_FOLLOWUP_TERMS
        ):
            return bool(self.recent_memory_subject(conversation_history))

        return False

    def normalized_recall_text(self, message: str) -> str:
        normalized = " ".join(str(message or "").lower().split())
        return re.sub(r"\bchet\b", "chat", normalized)

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
                    "anything about",
                    "talking about",
                    "information about",
                    "what do you know about",
                    "what do you remember about",
                )
            ):
                return content
        return ""

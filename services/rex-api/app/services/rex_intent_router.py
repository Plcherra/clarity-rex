from dataclasses import dataclass
from enum import Enum
import re
from typing import Optional

from app.services.recall_intent_helper import RecallIntentHelper


class RexIntent(str, Enum):
    CASUAL = "casual"
    MEMORY_SAVE = "memory_save"
    MEMORY_UPDATE = "memory_update"
    MEMORY_RECALL = "memory_recall"
    GOAL_OR_COMMITMENT = "goal_or_commitment"
    FINANCE = "finance"
    DEEP_REASONING = "deep_reasoning"
    UNKNOWN = "unknown"


@dataclass(frozen=True)
class RexIntentDecision:
    intent: RexIntent
    reasons: tuple[str, ...] = ()
    has_file: bool = False
    has_financial_context: bool = False
    finance_relevant: bool = False
    user_requested_deep_thinking: bool = False
    load_structured_memory_override: Optional[bool] = None

    @property
    def should_load_long_term_memory(self) -> bool:
        return self.intent in {
            RexIntent.MEMORY_UPDATE,
            RexIntent.MEMORY_RECALL,
            RexIntent.DEEP_REASONING,
            RexIntent.UNKNOWN,
        }

    @property
    def should_load_profile_memory(self) -> bool:
        return self.should_load_long_term_memory

    @property
    def should_load_structured_memory(self) -> bool:
        if self.load_structured_memory_override is not None:
            return self.load_structured_memory_override
        return self.intent in {
            RexIntent.MEMORY_UPDATE,
            RexIntent.MEMORY_RECALL,
            RexIntent.DEEP_REASONING,
            RexIntent.UNKNOWN,
        }

    @property
    def should_load_goal_context(self) -> bool:
        return self.intent in {
            RexIntent.GOAL_OR_COMMITMENT,
            RexIntent.DEEP_REASONING,
            RexIntent.UNKNOWN,
        }

    @property
    def should_load_accountability(self) -> bool:
        return self.intent in {
            RexIntent.GOAL_OR_COMMITMENT,
            RexIntent.DEEP_REASONING,
        }

    @property
    def should_use_financial_context(self) -> bool:
        return self.finance_relevant


class RexIntentRouter:
    def __init__(self, recall_intent: Optional[RecallIntentHelper] = None) -> None:
        self.recall_intent = recall_intent or RecallIntentHelper()

    DEEP_TERMS = (
        "deep think",
        "think deeply",
        "go deeper",
        "full analysis",
        "analyze thoroughly",
        "reason through",
        "break this down",
    )
    MEMORY_UPDATE_TERMS = (
        "actually",
        "correct that",
        "correction",
        "change that",
        "update that",
        "replace",
        "no, it's",
        "no it's",
        "not the",
        "not my",
        "not his",
        "not her",
        "it's not",
        "it is not",
        "with one m",
        "with two m",
        "spelled",
    )
    MEMORY_SAVE_TERMS = (
        "remember",
        "save this",
        "keep that in memory",
        "keep this in memory",
        "my name is",
        "i live in",
        "i work at",
        "my birthday is",
        "birthday is",
        "i prefer",
        "i like",
        "i hate",
    )
    MEMORY_STORE_TERMS = (
        "chat",
        "chats",
        "conversation",
        "conversations",
        "memory",
        "memories",
        "mention",
        "mentioned",
        "remember",
        "said",
        "saved",
        "say",
        "talked",
        "told you",
    )
    RECALL_BEFORE_UPDATE_TERMS = (
        "chat",
        "chats",
        "conversation",
        "conversations",
        "do you remember",
        "find",
        "mention",
        "mentioned",
        "said",
        "search",
        "talked",
        "told",
        "what did i say",
    )
    MEMORY_DELETE_TERMS = (
        "archive",
        "clear",
        "delete",
        "erase",
        "forget",
        "get rid of",
        "remove",
    )
    GOAL_TERMS = (
        "accountability",
        "behind",
        "commitment",
        "commitments",
        "deadline",
        "deadlines",
        "goal",
        "goals",
        "milestone",
        "milestones",
        "my plan",
        "my plans",
        "on track",
        "progress",
        "target",
        "targets",
        "remind me",
        "reminder",
        "send $",
        "send her $",
        "send him $",
        "doordash",
        "uber eats",
        "again",
    )
    ACCOUNTABILITY_STRUCTURED_TERMS = (
        "accountability",
        "again",
        "behind",
        "commitment",
        "commitments",
        "deadline",
        "deadlines",
        "doordash",
        "missed",
        "overdue",
        "rule",
        "rules",
        "uber eats",
    )
    FINANCE_TERMS = (
        "account balance",
        "bank",
        "budget",
        "cash",
        "debt",
        "expense",
        "expenses",
        "finance",
        "financial",
        "income",
        "money",
        "rent",
        "saving",
        "spend",
        "spent",
        "spending",
        "transaction",
        "transactions",
        "$",
    )
    CASUAL_EXACT = {
        "hey",
        "hi",
        "hello",
        "hello rex",
        "hey rex",
        "good morning",
        "good afternoon",
        "good evening",
        "thanks",
        "thank you",
        "thank you rex",
        "ok",
        "okay",
    }
    CASUAL_TERMS = (
        "how are you",
        "how's your day",
        "how is your day",
        "how's your night",
        "how is your night",
        "what's up",
    )

    def classify(
        self,
        message: str,
        *,
        has_file: bool = False,
        has_financial_context: bool = False,
        user_requested_deep_thinking: bool = False,
    ) -> RexIntentDecision:
        normalized = " ".join(message.lower().split())
        reasons: list[str] = []
        finance_relevant = self._has_finance_language(normalized)

        if user_requested_deep_thinking or self._contains(normalized, self.DEEP_TERMS):
            reasons.append("deep_reasoning_requested")
            return self._decision(
                RexIntent.DEEP_REASONING,
                reasons,
                has_file,
                has_financial_context,
                finance_relevant,
                user_requested_deep_thinking,
            )

        if self._looks_like_memory_recall_question(normalized) and self._contains(
            normalized,
            self.RECALL_BEFORE_UPDATE_TERMS,
        ):
            reasons.append("memory_recall_question")
            return self._decision(
                RexIntent.MEMORY_RECALL,
                reasons,
                has_file,
                has_financial_context,
                False,
                user_requested_deep_thinking,
            )

        if self._contains(normalized, self.MEMORY_UPDATE_TERMS):
            reasons.append("memory_update_language")
            return self._decision(
                RexIntent.MEMORY_UPDATE,
                reasons,
                has_file,
                has_financial_context,
                False,
                user_requested_deep_thinking,
            )

        if self._looks_like_memory_save(normalized):
            reasons.append("memory_save_language")
            return self._decision(
                RexIntent.MEMORY_SAVE,
                reasons,
                has_file,
                has_financial_context,
                False,
                user_requested_deep_thinking,
            )

        if self._looks_like_memory_delete(normalized):
            reasons.append("memory_delete_language")
            return self._decision(
                RexIntent.MEMORY_UPDATE,
                reasons,
                has_file,
                has_financial_context,
                False,
                user_requested_deep_thinking,
                load_structured_memory_override=True,
            )

        if self._looks_like_memory_recall_question(normalized):
            reasons.append("memory_recall_question")
            return self._decision(
                RexIntent.MEMORY_RECALL,
                reasons,
                has_file,
                has_financial_context,
                False,
                user_requested_deep_thinking,
            )

        if self._contains(normalized, self.GOAL_TERMS):
            if self._contains(normalized, self.ACCOUNTABILITY_STRUCTURED_TERMS):
                reasons.append("accountability_structured_language")
                load_structured_memory_override = True
            else:
                reasons.append("goal_or_commitment_language")
                load_structured_memory_override = False
            return self._decision(
                RexIntent.GOAL_OR_COMMITMENT,
                reasons,
                has_file,
                has_financial_context,
                finance_relevant,
                user_requested_deep_thinking,
                load_structured_memory_override=load_structured_memory_override,
            )

        if finance_relevant:
            reasons.append("finance_language")
            return self._decision(
                RexIntent.FINANCE,
                reasons,
                has_file,
                has_financial_context,
                True,
                user_requested_deep_thinking,
            )

        if normalized in self.CASUAL_EXACT or self._contains(
            normalized,
            self.CASUAL_TERMS,
        ):
            reasons.append("casual_language")
            return self._decision(
                RexIntent.CASUAL,
                reasons,
                has_file,
                has_financial_context,
                False,
                user_requested_deep_thinking,
            )

        reasons.append("fallback_unknown")
        return self._decision(
            RexIntent.UNKNOWN,
            reasons,
            has_file,
            has_financial_context,
            False,
            user_requested_deep_thinking,
        )

    def _decision(
        self,
        intent: RexIntent,
        reasons: list[str],
        has_file: bool,
        has_financial_context: bool,
        finance_relevant: bool,
        user_requested_deep_thinking: bool,
        load_structured_memory_override: Optional[bool] = None,
    ) -> RexIntentDecision:
        return RexIntentDecision(
            intent=intent,
            reasons=tuple(reasons),
            has_file=has_file,
            has_financial_context=has_financial_context,
            finance_relevant=finance_relevant,
            user_requested_deep_thinking=user_requested_deep_thinking,
            load_structured_memory_override=load_structured_memory_override,
        )

    def _contains(self, normalized_message: str, terms: tuple[str, ...]) -> bool:
        return any(term in normalized_message for term in terms)

    def _has_finance_language(self, normalized_message: str) -> bool:
        if self._contains(normalized_message, self.FINANCE_TERMS):
            return True
        return (
            re.search(
                r"\b(?:account|accounts|balance|balances|merchant|merchants|"
                r"plaid|subscription|subscriptions)\b",
                normalized_message,
            )
            is not None
            or re.search(r"\bcash(?:\s|-)?flow\b", normalized_message) is not None
        )

    def _looks_like_memory_recall_question(self, normalized_message: str) -> bool:
        if self._is_finance_first_query(normalized_message):
            return False

        return self.recall_intent.is_router_memory_recall_request(
            normalized_message,
        )

    def _is_finance_first_query(self, normalized_message: str) -> bool:
        if not self._has_finance_language(normalized_message):
            return False
        return not self._contains(normalized_message, self.MEMORY_STORE_TERMS)

    def _looks_like_memory_save(self, normalized_message: str) -> bool:
        if normalized_message.startswith(("do you remember", "what do you remember")):
            return False
        if normalized_message.startswith("remember what"):
            return False
        if normalized_message.startswith(
            ("remember any", "remember if", "remember whether")
        ):
            return False
        if normalized_message.startswith("remember ") and self._contains(
            normalized_message,
            (
                "anything",
                "chat",
                "conversation",
                "mentioned",
                "old",
                "search",
                "talked about",
                "what",
            ),
        ):
            return False
        if normalized_message.startswith("remember "):
            return True
        if " please remember " in f" {normalized_message} ":
            return True
        if normalized_message.startswith(
            (
                "can ",
                "could ",
                "do ",
                "does ",
                "how ",
                "what ",
                "when ",
                "where ",
                "who ",
            )
        ):
            return False
        return self._contains(
            normalized_message,
            tuple(term for term in self.MEMORY_SAVE_TERMS if term != "remember"),
        )

    def _looks_like_memory_delete(self, normalized_message: str) -> bool:
        if not self._contains(normalized_message, self.MEMORY_DELETE_TERMS):
            return False
        if self._is_finance_first_query(normalized_message):
            return False
        return (
            self._contains(normalized_message, self.MEMORY_STORE_TERMS)
            or re.search(
                r"\b(?:card|event|fact|item|knows|knowledge|note|person|people|record|that|this|it)\b",
                normalized_message,
            )
            is not None
        )

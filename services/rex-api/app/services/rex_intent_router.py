from dataclasses import dataclass
from enum import Enum
from typing import Optional

from app.services.goal_command_parsing import is_goals_inventory_query
from app.services.recall_intent_helper import RecallIntentHelper
from app.services.rex_intent_finance import RexIntentFinanceHelper
from app.services.rex_intent_memory import RexIntentMemoryHelper
from app.services.rex_intent_patterns import (
    ACCOUNTABILITY_STRUCTURED_TERMS,
    CASUAL_EXACT,
    CASUAL_TERMS,
    DEEP_TERMS,
    GOAL_TERMS,
    MEMORY_UPDATE_TERMS,
    RECALL_BEFORE_UPDATE_TERMS,
    contains,
)


class RexIntent(str, Enum):
    CASUAL = "casual"
    MEMORY_SAVE = "memory_save"
    MEMORY_UPDATE = "memory_update"
    MEMORY_RECALL = "memory_recall"
    GOAL = "goal"
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
            RexIntent.GOAL,
            RexIntent.DEEP_REASONING,
            RexIntent.UNKNOWN,
        }

    @property
    def should_load_accountability(self) -> bool:
        return self.intent in {
            RexIntent.GOAL,
            RexIntent.DEEP_REASONING,
        }

    @property
    def should_use_financial_context(self) -> bool:
        return self.finance_relevant


class RexIntentRouter:
    def __init__(self, recall_intent: Optional[RecallIntentHelper] = None) -> None:
        self.recall_intent = recall_intent or RecallIntentHelper()
        self.finance_helper = RexIntentFinanceHelper()
        self.memory_helper = RexIntentMemoryHelper(
            self.recall_intent,
            self.finance_helper,
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
        finance_relevant = self.finance_helper.has_finance_language(normalized)

        if user_requested_deep_thinking or contains(normalized, DEEP_TERMS):
            reasons.append("deep_reasoning_requested")
            return self._decision(
                RexIntent.DEEP_REASONING,
                reasons,
                has_file,
                has_financial_context,
                finance_relevant,
                user_requested_deep_thinking,
            )

        if is_goals_inventory_query(message):
            reasons.append("goals_inventory_query")
            return self._decision(
                RexIntent.GOAL,
                reasons,
                has_file,
                has_financial_context,
                finance_relevant,
                user_requested_deep_thinking,
                load_structured_memory_override=True,
            )

        if self.memory_helper.looks_like_memory_recall_question(
            normalized,
        ) and contains(normalized, RECALL_BEFORE_UPDATE_TERMS):
            reasons.append("memory_recall_question")
            return self._decision(
                RexIntent.MEMORY_RECALL,
                reasons,
                has_file,
                has_financial_context,
                False,
                user_requested_deep_thinking,
            )

        if contains(normalized, MEMORY_UPDATE_TERMS):
            reasons.append("memory_update_language")
            return self._decision(
                RexIntent.MEMORY_UPDATE,
                reasons,
                has_file,
                has_financial_context,
                False,
                user_requested_deep_thinking,
            )

        if self.memory_helper.looks_like_memory_save(normalized):
            reasons.append("memory_save_language")
            return self._decision(
                RexIntent.MEMORY_SAVE,
                reasons,
                has_file,
                has_financial_context,
                False,
                user_requested_deep_thinking,
            )

        if self.memory_helper.looks_like_memory_delete(normalized):
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

        if self.memory_helper.looks_like_memory_recall_question(normalized):
            reasons.append("memory_recall_question")
            return self._decision(
                RexIntent.MEMORY_RECALL,
                reasons,
                has_file,
                has_financial_context,
                False,
                user_requested_deep_thinking,
            )

        if contains(normalized, GOAL_TERMS):
            if contains(normalized, ACCOUNTABILITY_STRUCTURED_TERMS):
                reasons.append("accountability_structured_language")
                load_structured_memory_override = True
            else:
                reasons.append("goal_language")
                load_structured_memory_override = False
            return self._decision(
                RexIntent.GOAL,
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

        if normalized in CASUAL_EXACT or contains(normalized, CASUAL_TERMS):
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

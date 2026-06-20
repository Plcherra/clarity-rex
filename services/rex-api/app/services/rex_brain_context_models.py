"""Experimental layered Rex Brain context models.

NON-PRODUCTION FOR LAUNCH.

MVP production chat and voice use ChatService + SimpleRexBrain.
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Optional

from app.services.rex_brain_contracts import RexContextBudget


class RexFinancialContextScope(str, Enum):
    NONE = "none"
    SUMMARY_ONLY = "summary_only"
    CURRENT_MONTH_ROLLUP = "current_month_rollup"
    FULL_ROLLUP = "full_rollup"
    SELECTED_RECORDS = "selected_records"


@dataclass(frozen=True)
class RexContextBudgetLimits:
    total_characters: int
    financial_characters: int
    memory_characters: int
    structured_characters: int
    accountability_characters: int
    recent_chat_characters: int


@dataclass(frozen=True)
class RexBrainContext:
    context_budget: RexContextBudget
    financial_scope: RexFinancialContextScope = RexFinancialContextScope.NONE
    financial_context: Optional[dict[str, Any]] = None
    relevant_memories: tuple[dict[str, Any], ...] = field(default_factory=tuple)
    structured_context: dict[str, tuple[dict[str, Any], ...]] = field(default_factory=dict)
    accountability_signals: tuple[dict[str, Any], ...] = field(default_factory=tuple)
    recent_messages: tuple[dict[str, str], ...] = field(default_factory=tuple)
    diagnostics: tuple[str, ...] = field(default_factory=tuple)
    character_count: int = 0

    def metadata(self) -> dict[str, Any]:
        return {
            "context_budget": self.context_budget.value,
            "financial_scope": self.financial_scope.value,
            "financial_context_present": self.financial_context is not None,
            "memory_count": len(self.relevant_memories),
            "structured_counts": {
                key: len(value) for key, value in self.structured_context.items()
            },
            "accountability_signal_count": len(self.accountability_signals),
            "recent_message_count": len(self.recent_messages),
            "diagnostics": list(self.diagnostics),
            "character_count": self.character_count,
        }


BUDGET_LIMITS: dict[RexContextBudget, RexContextBudgetLimits] = {
    RexContextBudget.TINY: RexContextBudgetLimits(
        total_characters=1200,
        financial_characters=0,
        memory_characters=300,
        structured_characters=300,
        accountability_characters=200,
        recent_chat_characters=400,
    ),
    RexContextBudget.SMALL: RexContextBudgetLimits(
        total_characters=4000,
        financial_characters=1200,
        memory_characters=1000,
        structured_characters=1000,
        accountability_characters=500,
        recent_chat_characters=800,
    ),
    RexContextBudget.MEDIUM: RexContextBudgetLimits(
        total_characters=9000,
        financial_characters=3500,
        memory_characters=1800,
        structured_characters=2200,
        accountability_characters=900,
        recent_chat_characters=1200,
    ),
    RexContextBudget.HIGH: RexContextBudgetLimits(
        total_characters=16000,
        financial_characters=7000,
        memory_characters=2500,
        structured_characters=3200,
        accountability_characters=1300,
        recent_chat_characters=1800,
    ),
}

SENSITIVE_KEY_PARTS = (
    "access_token",
    "authorization",
    "credential",
    "password",
    "private_key",
    "refresh_token",
    "secret",
    "service_role",
)

FINANCIAL_SUMMARY_KEYS = (
    "schema",
    "generated_at",
    "data_status",
    "load_errors",
    "integration",
    "retrieval",
    "available_controls",
    "period",
    "cash_flow",
    "budget",
)
FINANCIAL_ROLLUP_KEYS = (
    "top_spending_categories",
    "biggest_month_over_month_increases",
    "budget_alerts",
    "accounts",
    "categories",
    "budgets",
    "transaction_slices",
    "review_queue",
    "statement_imports",
)
RAW_FINANCIAL_RECORD_KEYS = {"transactions"}
STRUCTURED_CONTEXT_KEYS = (
    "personal_rules",
    "plans",
    "plan_milestones",
    "commitments",
    "entities",
    "entity_events",
)

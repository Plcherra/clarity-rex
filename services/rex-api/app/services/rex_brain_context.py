from typing import Any, Optional

from app.services.rex_brain_context_budgeting import _enforce_total_budget
from app.services.rex_brain_context_models import (
    BUDGET_LIMITS,
    RexBrainContext,
    RexContextBudgetLimits,
    RexFinancialContextScope,
)
from app.services.rex_brain_context_selection import (
    _financial_scope_for_decision,
    _select_accountability_signals,
    _select_financial_context,
    _select_memory_context,
    _select_recent_messages,
    _select_structured_context,
)
from app.services.rex_brain_contracts import RexBrainDecision


def build_rex_brain_context(
    *,
    decision: RexBrainDecision,
    recent_messages: Optional[list[dict[str, Any]]] = None,
    financial_context: Optional[dict[str, Any]] = None,
    relevant_memories: Optional[list[dict[str, Any]]] = None,
    structured_context: Optional[dict[str, list[dict[str, Any]]]] = None,
    accountability_signals: Optional[list[Any]] = None,
) -> RexBrainContext:
    limits = BUDGET_LIMITS[decision.context_budget]
    diagnostics: list[str] = []
    financial_scope = _financial_scope_for_decision(decision)
    selected_financial = _select_financial_context(
        financial_context,
        financial_scope,
        limits.financial_characters,
        diagnostics,
    )
    selected_memories = tuple(
        _select_memory_context(
            relevant_memories or [],
            decision,
            limits.memory_characters,
            diagnostics,
        )
    )
    selected_structured = _select_structured_context(
        structured_context or {},
        decision,
        limits.structured_characters,
        diagnostics,
    )
    selected_accountability = tuple(
        _select_accountability_signals(
            accountability_signals or [],
            decision,
            limits.accountability_characters,
            diagnostics,
        )
    )
    selected_recent_messages = tuple(
        _select_recent_messages(
            recent_messages or [],
            limits.recent_chat_characters,
            diagnostics,
        )
    )
    context = RexBrainContext(
        context_budget=decision.context_budget,
        financial_scope=financial_scope,
        financial_context=selected_financial,
        relevant_memories=selected_memories,
        structured_context=selected_structured,
        accountability_signals=selected_accountability,
        recent_messages=selected_recent_messages,
        diagnostics=tuple(dict.fromkeys(diagnostics)),
    )
    return _enforce_total_budget(context, limits, diagnostics)

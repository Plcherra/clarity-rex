"""Experimental layered Rex Brain context budgeting.

NON-PRODUCTION FOR LAUNCH.

MVP production chat and voice use ChatService + SimpleRexBrain.
"""

from typing import Any

from app.services.rex_brain_context_models import (
    RexBrainContext,
    RexContextBudgetLimits,
    STRUCTURED_CONTEXT_KEYS,
)
from app.services.rex_brain_context_utils import (
    _estimate_characters,
    _fit_mapping_to_budget,
)


def _enforce_total_budget(
    context: RexBrainContext,
    limits: RexContextBudgetLimits,
    diagnostics: list[str],
) -> RexBrainContext:
    context = _with_character_count(context, diagnostics)
    if context.character_count <= limits.total_characters:
        return context

    diagnostics.append("context_total_budget_exceeded")
    context = _with_character_count(context, diagnostics)

    while context.character_count > limits.total_characters and context.recent_messages:
        diagnostics.append("recent_chat_context_trimmed_for_total")
        context = _with_character_count(
            _replace_context(
                context,
                recent_messages=context.recent_messages[1:],
            ),
            diagnostics,
        )

    while (
        context.character_count > limits.total_characters
        and context.accountability_signals
    ):
        diagnostics.append("accountability_context_trimmed_for_total")
        context = _with_character_count(
            _replace_context(
                context,
                accountability_signals=context.accountability_signals[:-1],
            ),
            diagnostics,
        )

    while context.character_count > limits.total_characters and _structured_record_count(
        context.structured_context,
    ):
        diagnostics.append("structured_context_trimmed_for_total")
        context = _with_character_count(
            _replace_context(
                context,
                structured_context=_drop_last_structured_record(
                    context.structured_context,
                ),
            ),
            diagnostics,
        )

    while context.character_count > limits.total_characters and context.relevant_memories:
        diagnostics.append("memory_context_trimmed_for_total")
        context = _with_character_count(
            _replace_context(
                context,
                relevant_memories=context.relevant_memories[:-1],
            ),
            diagnostics,
        )

    if context.character_count > limits.total_characters and context.financial_context:
        available_financial_characters = max(
            limits.total_characters
            - _context_character_count(
                _replace_context(context, financial_context=None),
            ),
            0,
        )
        fitted_financial = _fit_mapping_to_budget(
            context.financial_context,
            available_financial_characters,
            diagnostics,
            "financial_context_trimmed_for_total",
        )
        context = _with_character_count(
            _replace_context(
                context,
                financial_context=fitted_financial or None,
            ),
            diagnostics,
        )

    if context.character_count > limits.total_characters:
        diagnostics.append("context_total_budget_minimal_fallback")
        context = _with_character_count(
            _replace_context(
                context,
                financial_context=None,
                relevant_memories=(),
                structured_context={},
                accountability_signals=(),
                recent_messages=(),
            ),
            diagnostics,
        )

    return _with_character_count(context, diagnostics)


def _replace_context(
    context: RexBrainContext,
    *,
    financial_context: Any = ...,
    relevant_memories: Any = ...,
    structured_context: Any = ...,
    accountability_signals: Any = ...,
    recent_messages: Any = ...,
) -> RexBrainContext:
    return RexBrainContext(
        context_budget=context.context_budget,
        financial_scope=context.financial_scope,
        financial_context=(
            context.financial_context
            if financial_context is ...
            else financial_context
        ),
        relevant_memories=(
            context.relevant_memories
            if relevant_memories is ...
            else relevant_memories
        ),
        structured_context=(
            context.structured_context
            if structured_context is ...
            else structured_context
        ),
        accountability_signals=(
            context.accountability_signals
            if accountability_signals is ...
            else accountability_signals
        ),
        recent_messages=(
            context.recent_messages
            if recent_messages is ...
            else recent_messages
        ),
        diagnostics=context.diagnostics,
        character_count=0,
    )


def _with_character_count(
    context: RexBrainContext,
    diagnostics: list[str],
) -> RexBrainContext:
    unique_diagnostics = tuple(dict.fromkeys(diagnostics))
    context = RexBrainContext(
        context_budget=context.context_budget,
        financial_scope=context.financial_scope,
        financial_context=context.financial_context,
        relevant_memories=context.relevant_memories,
        structured_context=context.structured_context,
        accountability_signals=context.accountability_signals,
        recent_messages=context.recent_messages,
        diagnostics=unique_diagnostics,
        character_count=0,
    )
    return RexBrainContext(
        context_budget=context.context_budget,
        financial_scope=context.financial_scope,
        financial_context=context.financial_context,
        relevant_memories=context.relevant_memories,
        structured_context=context.structured_context,
        accountability_signals=context.accountability_signals,
        recent_messages=context.recent_messages,
        diagnostics=context.diagnostics,
        character_count=_context_character_count(context),
    )


def _context_character_count(context: RexBrainContext) -> int:
    return _estimate_characters(
        {
            "financial_context": context.financial_context,
            "relevant_memories": context.relevant_memories,
            "structured_context": context.structured_context,
            "accountability_signals": context.accountability_signals,
            "recent_messages": context.recent_messages,
            "diagnostics": context.diagnostics,
        }
    )


def _structured_record_count(
    structured_context: dict[str, tuple[dict[str, Any], ...]],
) -> int:
    return sum(len(records) for records in structured_context.values())


def _drop_last_structured_record(
    structured_context: dict[str, tuple[dict[str, Any], ...]],
) -> dict[str, tuple[dict[str, Any], ...]]:
    next_context = dict(structured_context)
    for key in reversed(STRUCTURED_CONTEXT_KEYS):
        records = next_context.get(key)
        if not records:
            continue
        trimmed = records[:-1]
        if trimmed:
            next_context[key] = trimmed
        else:
            next_context.pop(key, None)
        break
    return next_context

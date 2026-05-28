from copy import deepcopy
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Optional

from app.services.rex_brain_contracts import (
    RexBrainDecision,
    RexContextBudget,
    RexThinkingLayer,
)


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


def _financial_scope_for_decision(
    decision: RexBrainDecision,
) -> RexFinancialContextScope:
    if not decision.needs_financial_context:
        return RexFinancialContextScope.NONE
    if decision.layer == RexThinkingLayer.STRATEGIC:
        return RexFinancialContextScope.FULL_ROLLUP
    if decision.context_budget == RexContextBudget.HIGH:
        return RexFinancialContextScope.SELECTED_RECORDS
    if decision.context_budget == RexContextBudget.MEDIUM:
        return RexFinancialContextScope.CURRENT_MONTH_ROLLUP
    return RexFinancialContextScope.SUMMARY_ONLY


def _select_financial_context(
    financial_context: Optional[dict[str, Any]],
    scope: RexFinancialContextScope,
    character_budget: int,
    diagnostics: list[str],
) -> Optional[dict[str, Any]]:
    if scope == RexFinancialContextScope.NONE:
        return None
    if not financial_context:
        diagnostics.append("financial_context_missing")
        return None

    safe_context = _sanitize_value(financial_context)
    if isinstance(safe_context, dict):
        for error in safe_context.get("load_errors") or []:
            diagnostics.append(f"financial_context_degraded:{error}")
        if safe_context.get("data_status") in {"degraded", "partial"}:
            diagnostics.append(f"financial_context_{safe_context.get('data_status')}")

    if scope == RexFinancialContextScope.SUMMARY_ONLY:
        selected = _copy_keys(safe_context, FINANCIAL_SUMMARY_KEYS)
    elif scope == RexFinancialContextScope.CURRENT_MONTH_ROLLUP:
        selected = _copy_keys(safe_context, FINANCIAL_SUMMARY_KEYS + FINANCIAL_ROLLUP_KEYS)
        selected.pop("transactions", None)
    elif scope == RexFinancialContextScope.FULL_ROLLUP:
        selected = _copy_keys(safe_context, FINANCIAL_SUMMARY_KEYS + FINANCIAL_ROLLUP_KEYS)
        selected.pop("transactions", None)
    else:
        selected = _copy_keys(
            safe_context,
            FINANCIAL_SUMMARY_KEYS + FINANCIAL_ROLLUP_KEYS + tuple(RAW_FINANCIAL_RECORD_KEYS),
        )

    return _fit_mapping_to_budget(
        selected,
        character_budget,
        diagnostics,
        "financial_context_truncated",
    )


def _select_memory_context(
    memories: list[dict[str, Any]],
    decision: RexBrainDecision,
    character_budget: int,
    diagnostics: list[str],
) -> list[dict[str, Any]]:
    if not decision.needs_memory_context:
        return []
    ranked = sorted(memories, key=_memory_rank_key)
    return _fit_records_to_budget(
        ranked,
        character_budget,
        diagnostics,
        "memory_context_truncated",
    )


def _select_structured_context(
    structured_context: dict[str, list[dict[str, Any]]],
    decision: RexBrainDecision,
    character_budget: int,
    diagnostics: list[str],
) -> dict[str, tuple[dict[str, Any], ...]]:
    if not decision.needs_memory_context:
        return {}
    if not structured_context:
        return {}

    selected: dict[str, tuple[dict[str, Any], ...]] = {}
    used_characters = 0
    for key in STRUCTURED_CONTEXT_KEYS:
        records = structured_context.get(key) or []
        ranked_records = sorted(records, key=_structured_rank_key)
        bucket: list[dict[str, Any]] = []
        for record in ranked_records:
            safe_record = _sanitize_value(record)
            record_size = _estimate_characters(safe_record)
            if used_characters + record_size > character_budget:
                diagnostics.append("structured_context_truncated")
                break
            bucket.append(safe_record)
            used_characters += record_size
        if bucket:
            selected[key] = tuple(bucket)
    return selected


def _select_accountability_signals(
    accountability_signals: list[Any],
    decision: RexBrainDecision,
    character_budget: int,
    diagnostics: list[str],
) -> list[dict[str, Any]]:
    if decision.layer not in {
        RexThinkingLayer.STRATEGIC,
        RexThinkingLayer.COACHING,
        RexThinkingLayer.REFLECTIVE,
    }:
        return []
    normalized = [_signal_to_dict(signal) for signal in accountability_signals]
    ranked = sorted(normalized, key=_accountability_rank_key)
    return _fit_records_to_budget(
        ranked,
        character_budget,
        diagnostics,
        "accountability_context_truncated",
    )


def _select_recent_messages(
    recent_messages: list[dict[str, Any]],
    character_budget: int,
    diagnostics: list[str],
) -> list[dict[str, str]]:
    selected: list[dict[str, str]] = []
    used_characters = 0
    for message in reversed(recent_messages):
        role = message.get("role")
        content = str(message.get("content") or "")
        if role not in {"user", "assistant", "system"} or not content:
            continue
        available_characters = character_budget - used_characters
        if available_characters <= 60:
            diagnostics.append("recent_chat_context_truncated")
            break
        content_limit = min(600, max(40, available_characters - 40))
        safe_message = {"role": str(role), "content": _truncate(content, content_limit)}
        message_size = _estimate_characters(safe_message)
        if used_characters + message_size > character_budget:
            diagnostics.append("recent_chat_context_truncated")
            break
        selected.append(safe_message)
        used_characters += message_size
    return list(reversed(selected))


def _fit_mapping_to_budget(
    value: dict[str, Any],
    character_budget: int,
    diagnostics: list[str],
    diagnostic: str,
) -> dict[str, Any]:
    if character_budget <= 0:
        diagnostics.append(diagnostic)
        return {}
    selected: dict[str, Any] = {}
    for key, item in value.items():
        candidate = {**selected, key: item}
        if _estimate_characters(candidate) <= character_budget:
            selected[key] = item
            continue
        if isinstance(item, list):
            fitted = _fit_records_to_budget(
                item,
                max(character_budget - _estimate_characters(selected), 0),
                diagnostics,
                diagnostic,
            )
            if fitted:
                selected[key] = fitted
            else:
                diagnostics.append(diagnostic)
            break
        diagnostics.append(diagnostic)
        break
    return selected


def _fit_records_to_budget(
    records: list[dict[str, Any]],
    character_budget: int,
    diagnostics: list[str],
    diagnostic: str,
) -> list[dict[str, Any]]:
    selected: list[dict[str, Any]] = []
    used_characters = 0
    for record in records:
        safe_record = _sanitize_value(record)
        record_size = _estimate_characters(safe_record)
        if used_characters + record_size > character_budget:
            diagnostics.append(diagnostic)
            break
        selected.append(safe_record)
        used_characters += record_size
    return selected


def _copy_keys(value: dict[str, Any], keys: tuple[str, ...]) -> dict[str, Any]:
    return {key: deepcopy(value[key]) for key in keys if key in value}


def _sanitize_value(value: Any) -> Any:
    if isinstance(value, dict):
        result: dict[str, Any] = {}
        for key, item in value.items():
            normalized_key = str(key).lower()
            if any(part in normalized_key for part in SENSITIVE_KEY_PARTS):
                continue
            result[str(key)] = _sanitize_value(item)
        return result
    if isinstance(value, list):
        return [_sanitize_value(item) for item in value]
    if isinstance(value, tuple):
        return tuple(_sanitize_value(item) for item in value)
    if isinstance(value, str):
        return _truncate(value, 1200)
    return value


def _truncate(value: str, max_characters: int) -> str:
    if len(value) <= max_characters:
        return value
    return f"{value[: max_characters - 14].rstrip()} [truncated]"


def _memory_rank_key(memory: dict[str, Any]) -> tuple[int, int, str]:
    memory_type = str(memory.get("memory_type") or memory.get("candidate_type") or "")
    content = str(memory.get("content") or memory.get("text") or "")
    is_correction = "correction" in memory_type.lower() or "correction" in content.lower()
    importance = _safe_int(memory.get("importance"), default=3)
    updated = str(memory.get("updated_at") or memory.get("created_at") or "")
    return (0 if is_correction else 1, -importance, _reverse_sortable_string(updated))


def _structured_rank_key(record: dict[str, Any]) -> tuple[int, str]:
    priority = _safe_int(
        record.get("priority", record.get("importance", record.get("severity", 3))),
        default=3,
    )
    updated = str(record.get("updated_at") or record.get("due_at") or record.get("target_date") or "")
    return (-priority, _reverse_sortable_string(updated))


def _accountability_rank_key(signal: dict[str, Any]) -> tuple[int, int, str]:
    severity_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    severity = str(signal.get("severity") or "medium").lower()
    priority = _safe_int(signal.get("priority"), default=3)
    created = str(signal.get("created_at") or signal.get("due_at") or "")
    return (severity_order.get(severity, 2), -priority, _reverse_sortable_string(created))


def _signal_to_dict(signal: Any) -> dict[str, Any]:
    if isinstance(signal, dict):
        return _sanitize_value(signal)
    if hasattr(signal, "model_dump"):
        return _sanitize_value(signal.model_dump())
    if hasattr(signal, "dict"):
        return _sanitize_value(signal.dict())
    return {"value": _truncate(str(signal), 600)}


def _estimate_characters(value: Any) -> int:
    return len(str(value))


def _safe_int(value: Any, *, default: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _reverse_sortable_string(value: str) -> str:
    # Keep newer ISO-like timestamps ahead in ascending tuple sorts.
    return "".join(chr(255 - ord(character)) for character in value[:64])

from typing import Any, Optional

from app.services.rex_brain_context_models import (
    FINANCIAL_ROLLUP_KEYS,
    FINANCIAL_SUMMARY_KEYS,
    RAW_FINANCIAL_RECORD_KEYS,
    STRUCTURED_CONTEXT_KEYS,
    RexFinancialContextScope,
)
from app.services.rex_brain_context_utils import (
    _accountability_rank_key,
    _copy_keys,
    _estimate_characters,
    _fit_mapping_to_budget,
    _fit_records_to_budget,
    _memory_rank_key,
    _sanitize_value,
    _signal_to_dict,
    _structured_rank_key,
    _truncate,
)
from app.services.rex_brain_contracts import (
    RexBrainDecision,
    RexContextBudget,
    RexThinkingLayer,
)


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
        data_status = safe_context.get("data_status")
        status_state = None
        load_errors = safe_context.get("load_errors")
        if isinstance(data_status, dict):
            status_state = data_status.get("state")
            nested_load_errors = data_status.get("load_errors")
            if nested_load_errors:
                load_errors = nested_load_errors

        if isinstance(load_errors, list):
            for error in load_errors:
                diagnostics.append(f"financial_context_degraded:{error}")
        elif load_errors:
            diagnostics.append("financial_context_degraded")

        if isinstance(data_status, str):
            status_state = data_status
        if isinstance(status_state, str) and status_state in {
            "unavailable",
            "degraded",
            "partial",
            "stale",
        }:
            diagnostics.append(f"financial_context_{status_state}")
        elif isinstance(data_status, dict) and status_state is None:
            diagnostics.append("financial_context_data_status_invalid")
        elif (
            data_status is not None
            and not isinstance(data_status, dict)
            and not isinstance(data_status, (str, int, float, bool))
        ):
            diagnostics.append("financial_context_data_status_invalid")

        freshness = safe_context.get("freshness")
        if isinstance(freshness, dict):
            freshness_state = freshness.get("state")
            if isinstance(freshness_state, str) and freshness_state in {
                "stale",
                "unknown",
            }:
                diagnostics.append(f"financial_context_freshness_{freshness_state}")

    if scope == RexFinancialContextScope.SUMMARY_ONLY:
        selected = _copy_keys(safe_context, FINANCIAL_SUMMARY_KEYS)
    elif scope == RexFinancialContextScope.CURRENT_MONTH_ROLLUP:
        selected = _copy_keys(
            safe_context, FINANCIAL_SUMMARY_KEYS + FINANCIAL_ROLLUP_KEYS
        )
        selected.pop("transactions", None)
    elif scope == RexFinancialContextScope.FULL_ROLLUP:
        selected = _copy_keys(
            safe_context, FINANCIAL_SUMMARY_KEYS + FINANCIAL_ROLLUP_KEYS
        )
        selected.pop("transactions", None)
    else:
        selected = _copy_keys(
            safe_context,
            FINANCIAL_SUMMARY_KEYS
            + FINANCIAL_ROLLUP_KEYS
            + tuple(RAW_FINANCIAL_RECORD_KEYS),
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
    memory_status = structured_context.get("memory_status")
    if isinstance(memory_status, dict):
        selected["memory_status"] = _sanitize_value(memory_status)
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

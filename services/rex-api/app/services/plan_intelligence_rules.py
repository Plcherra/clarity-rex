from __future__ import annotations

import re
from typing import Any, Optional

from app.services.plan_intelligence_models import PLAN_INTELLIGENCE_VERSION
from app.services.plan_intelligence_text import (
    candidate_text,
    clean,
    normalize_title,
    record_text,
    similarity,
    tokens,
)


def parent_plan_score(candidate: dict[str, Any], plan: dict[str, Any]) -> float:
    current_candidate_text = candidate_text(candidate)
    current_plan_text = record_text(plan)
    score = similarity(current_candidate_text, current_plan_text)
    candidate_type = str(candidate.get("plan_type") or "").lower()
    plan_type = str(plan.get("plan_type") or "").lower()
    if candidate_type and candidate_type == plan_type:
        score += 0.08
    elif candidate_type and plan_type and not compatible_plan_types(
        candidate_type,
        plan_type,
    ):
        score -= 0.18
    if candidate.get("primary_entity_id") == plan.get("primary_entity_id"):
        if candidate.get("primary_entity_id"):
            score += 0.22
    score += domain_bridge_score(current_candidate_text, current_plan_text)
    return min(score, 1.0)


def compatible_plan_types(candidate_type: str, plan_type: str) -> bool:
    compatible_groups = [
        {"career", "creative", "finance", "other"},
        {"finance", "immigration", "personal"},
        {"immigration", "housing", "personal"},
    ]
    return any({candidate_type, plan_type} <= group for group in compatible_groups)


def domain_bridge_score(candidate_value: str, plan_value: str) -> float:
    candidate_tokens = tokens(candidate_value)
    plan_tokens = tokens(plan_value)
    boost = 0.0
    if candidate_tokens & _INCOME_TERMS and plan_tokens & _RELOCATION_PLAN_TERMS:
        boost += 0.25
    if candidate_tokens & _RELOCATION_TERMS and plan_tokens & _RELOCATION_PLAN_TERMS:
        boost += 0.42
    if candidate_tokens & _APP_TERMS and plan_tokens & _APP_PLAN_TERMS:
        boost += 0.34
    if candidate_tokens & _DATING_BRIDGE_TERMS:
        if plan_tokens & {"date", "dating", "dinner", "relationship", "melissa"}:
            boost += 0.25
    return boost


def best_milestone_for_commitment(
    candidate: dict[str, Any],
    active_milestones: list[dict[str, Any]],
) -> Optional[dict[str, Any]]:
    if not active_milestones:
        return None
    current_candidate_text = candidate_text(candidate)
    best_milestone, best_score = max(
        (
            (milestone, similarity(current_candidate_text, record_text(milestone)))
            for milestone in active_milestones
            if milestone.get("active", True)
            and str(milestone.get("status") or "open") in {"open", "in_progress"}
        ),
        key=lambda item: item[1],
        default=(None, 0),
    )
    if best_score < 0.25:
        return None
    return best_milestone


def duplicate_milestone(
    candidate: dict[str, Any],
    active_milestones: list[dict[str, Any]],
) -> Optional[dict[str, Any]]:
    title = clean(candidate.get("title"))
    current_candidate_text = candidate_text(candidate)
    candidate_money = money_targets(current_candidate_text)
    for milestone in active_milestones:
        if not milestone.get("active", True):
            continue
        if str(milestone.get("status") or "open") not in {"open", "in_progress"}:
            continue
        milestone_title = clean(milestone.get("title"))
        milestone_text = record_text(milestone)
        if titles_equivalent(title, milestone_title):
            return milestone
        if similarity(current_candidate_text, milestone_text) >= 0.82:
            return milestone
        if candidate_money and candidate_money == money_targets(milestone_text):
            if tokens(current_candidate_text) & _MONEY_TARGET_TERMS:
                return milestone
    return None


def titles_equivalent(left: str, right: str) -> bool:
    left_key = normalize_title(left)
    right_key = normalize_title(right)
    if not left_key or not right_key:
        return False
    return left_key == right_key or similarity(left_key, right_key) >= 0.9


def money_targets(text: str) -> set[str]:
    targets = {
        match.group(0).lower().replace(",", "")
        for match in re.finditer(r"(?:[$€]\s*)?\d+(?:\.\d+)?\s*k", text, re.I)
    }
    targets.update(
        match.group(0).lower().replace(",", "")
        for match in re.finditer(r"[$€]\s*\d{3,}", text, re.I)
    )
    return targets


def is_small_step(candidate: dict[str, Any]) -> bool:
    text = candidate_text(candidate)
    if tokens(text) & _SMALL_STEP_TERMS:
        return True
    return bool(str(candidate.get("target_date") or "").strip())


def is_dating_logistics(
    candidate: dict[str, Any],
    parent_plan: dict[str, Any],
) -> bool:
    text = candidate_text(candidate)
    current_tokens = tokens(text)
    plan_type = str(
        candidate.get("plan_type") or parent_plan.get("plan_type") or ""
    ).lower()
    if plan_type != "dating" and "melissa" not in current_tokens:
        return False
    return bool(current_tokens & _DATING_LOGISTICS_TERMS)


def is_historical_context(text: str) -> bool:
    return bool(
        tokens(text)
        & {"told", "said", "invited", "hug", "matcha", "fired", "quit"}
    )


def is_first_million_exploration(text: str) -> bool:
    return "first million" in text or {"million", "worth"} <= tokens(text)


def is_badge_like_achievement(candidate: dict[str, Any]) -> bool:
    text = candidate_text(candidate)
    current_tokens = tokens(text)
    if money_targets(text):
        return True
    if re.search(r"\b\d+\s*(?:%|percent|users?|clients?|months?|weeks?)\b", text):
        return True
    if current_tokens & _ACHIEVEMENT_TERMS:
        return True
    if current_tokens & _APPLICATION_TERMS and current_tokens & _IMMIGRATION_TERMS:
        return True
    return False


def has_strategy_signal(text: str) -> bool:
    return bool(tokens(text) & _STRATEGY_TERMS)


def has_success_signal(text: str) -> bool:
    return bool(tokens(text) & _SUCCESS_TERMS)


def has_timeline_or_target(text: str) -> bool:
    if money_targets(text):
        return True
    return bool(re.search(_TIMELINE_PATTERN, text, re.I))


def specificity_score(
    candidate: dict[str, Any],
    *,
    small_step_penalty: bool = True,
) -> float:
    text = candidate_text(candidate)
    score = min(len(tokens(text)) / 14, 0.55)
    if clean(candidate.get("desired_outcome")):
        score += 0.18
    if clean(candidate.get("description")):
        score += 0.16
    if str(candidate.get("plan_type") or "").strip():
        score += 0.08
    if small_step_penalty and is_small_step(candidate):
        score -= 0.22
    return max(0.0, min(score, 1.0))


def has_standalone_anchor(candidate: dict[str, Any]) -> bool:
    plan_type = str(candidate.get("plan_type") or "").strip().lower()
    if plan_type not in _STANDALONE_PLAN_TYPES:
        return False
    return bool(
        clean(candidate.get("description"))
        or clean(candidate.get("desired_outcome"))
        or clean(candidate.get("entity_name"))
        or clean(candidate.get("primary_entity_id"))
    )


def milestone_type(candidate: dict[str, Any]) -> str:
    if str(candidate.get("target_date") or "").strip():
        return "deadline"
    if is_small_step(candidate):
        return "task"
    return "goal"


def commitment_type(candidate: dict[str, Any], parent_plan: dict[str, Any]) -> str:
    plan_type = str(
        candidate.get("plan_type") or parent_plan.get("plan_type") or ""
    ).lower()
    if plan_type in {"health", "immigration", "dating"}:
        return {"dating": "relationship"}.get(plan_type, plan_type)
    if plan_type in {"career", "creative"}:
        return "work"
    if plan_type == "finance":
        return "money"
    return "task"


_INCOME_TERMS = {
    "income",
    "revenue",
    "savings",
    "client",
    "clients",
    "freelance",
    "paycheck",
}

_RELOCATION_PLAN_TERMS = {
    "abroad",
    "citizenship",
    "europe",
    "freedom",
    "greece",
    "immigration",
    "income",
    "independent",
    "italy",
    "location",
    "move",
    "relocate",
    "relocation",
    "usa",
}

_RELOCATION_TERMS = {
    "abroad",
    "citizenship",
    "digital",
    "estonia",
    "europe",
    "greece",
    "immigration",
    "italian",
    "italy",
    "nomad",
    "portugal",
    "relocate",
    "relocation",
    "residency",
    "usa",
    "visa",
}

_APP_TERMS = {
    "app",
    "apps",
    "build",
    "clarity",
    "development",
    "echodesk",
    "flowforce",
    "launch",
    "mvp",
    "rex",
    "ship",
}

_APP_PLAN_TERMS = _APP_TERMS | {"project", "roadmap"}
_DATING_BRIDGE_TERMS = {"date", "dinner", "restaurant", "monday", "text", "melissa"}
_DATING_LOGISTICS_TERMS = {
    "date",
    "dinner",
    "monday",
    "restaurant",
    "outing",
    "meetup",
}
_MONEY_TARGET_TERMS = {"income", "monthly", "month", "revenue", "target"}
_SMALL_STEP_TERMS = {
    "confirm",
    "text",
    "message",
    "call",
    "book",
    "schedule",
    "send",
    "ask",
    "pay",
    "transfer",
    "email",
    "choose",
    "pick",
}
_ACHIEVEMENT_TERMS = {
    "achieve",
    "achieved",
    "approval",
    "approved",
    "complete",
    "completed",
    "finish",
    "finished",
    "hit",
    "launch",
    "launched",
    "mvp",
    "reach",
    "reached",
    "secure",
    "secured",
    "ship",
    "shipped",
    "submit",
    "submitted",
}
_APPLICATION_TERMS = {"application", "citizenship", "residency", "visa"}
_IMMIGRATION_TERMS = {
    "italian",
    "italy",
    "estonia",
    "portugal",
    "nomad",
    "digital",
}
_STRATEGY_TERMS = {
    "route",
    "strategy",
    "through",
    "using",
    "supported",
    "because",
    "plan",
    "launch",
    "apply",
    "build",
    "gain",
    "lift",
    "move",
    "track",
}
_SUCCESS_TERMS = {
    "success",
    "successful",
    "achieve",
    "achieved",
    "stable",
    "ready",
    "approved",
    "launched",
    "revenue",
    "income",
    "living",
}
_TIMELINE_PATTERN = (
    r"\b(?:january|february|march|april|may|june|july|august|september|"
    r"october|november|december|week|month|year|next|by)\b"
)
_STANDALONE_PLAN_TYPES = {
    "career",
    "creative",
    "dating",
    "finance",
    "health",
    "housing",
    "immigration",
    "personal",
}


def route_version() -> int:
    return PLAN_INTELLIGENCE_VERSION

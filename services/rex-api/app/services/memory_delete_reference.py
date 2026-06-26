from __future__ import annotations

import re

_VAGUE_DELETE_TARGETS = {
    "a memory",
    "memory",
    "memories",
    "a saved memory",
    "saved memory",
    "saved memories",
    "a memory please",
    "memory please",
    "a record",
    "record",
    "records",
}

_REFERENCE_DELETE_PATTERNS = (
    re.compile(
        r"\b(?:the\s+one|that\s+one)\s+"
        r"(?:starting\s+(?:as|with)|about|that\s+(?:says|starts(?:\s+as)?))\s+"
        r"['\"]?(.+?)['\"]?\s*$",
        re.IGNORECASE,
    ),
    re.compile(
        r"\bstarting\s+(?:as|with)\s+['\"]?(.+?)['\"]?\s*$",
        re.IGNORECASE,
    ),
)

_DELETE_CONTEXT_MARKERS = (
    "couldn't find an active saved memory",
    "could not find an active saved memory",
    "multiple active saved items",
    "tell me the exact saved item to delete",
    "exact saved item to delete",
)


def _normalize_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", str(value or "").lower()).strip()


def is_vague_delete_target(target: str) -> bool:
    normalized = _normalize_key(target)
    if not normalized:
        return True
    if normalized in _VAGUE_DELETE_TARGETS:
        return True
    tokens = normalized.split()
    return len(tokens) <= 3 and "memory" in tokens


def extract_reference_delete_target(text: str) -> str | None:
    cleaned = re.sub(r"\s+", " ", str(text or "")).strip()
    if not cleaned:
        return None
    for pattern in _REFERENCE_DELETE_PATTERNS:
        match = pattern.search(cleaned)
        if match is None:
            continue
        target = re.sub(r"[.!?]+$", "", match.group(1)).strip(" \"'")
        if target:
            return target
    return None


def is_delete_clarification_message(
    message: str,
    conversation_history: list[dict] | None = None,
) -> bool:
    from app.services.goal_command_parsing import is_goals_inventory_query

    if is_goals_inventory_query(message):
        return False
    if extract_reference_delete_target(message):
        return True
    if not conversation_history:
        return False
    for item in reversed(conversation_history[-8:]):
        if item.get("role") != "assistant":
            continue
        content = str(item.get("content") or "").lower()
        return any(marker in content for marker in _DELETE_CONTEXT_MARKERS)
    return False


def response_claims_delete_success(response: str) -> bool:
    text = f" {str(response or '').lower()} "
    return any(
        phrase in text
        for phrase in (
            " deleted ",
            " removed from saved memory",
            " removed from active saved memory",
            " has been removed ",
        )
    )


_DELETE_CONFIRMATION_REPLY = re.compile(
    r"^(?:yes(?:\s+please)?|yeah|yep|sure|ok(?:ay)?|confirmed?|do it|go ahead|"
    r"go ahead delete it|delete it|yes delete it)\.?$",
    re.IGNORECASE,
)

_DELETE_REJECTION_REPLY = re.compile(
    r"^(?:no(?:pe)?|cancel|do not|dont|don't)\.?$",
    re.IGNORECASE,
)

_DELETE_PROMPT_PATTERNS = (
    re.compile(
        r"delete this saved memory:\s*(.+?)(?:\n|$)",
        re.IGNORECASE,
    ),
    re.compile(
        r"do you want me to delete (?:the )?(?:commitment|goal)\s+['\"](.+?)['\"]",
        re.IGNORECASE,
    ),
    re.compile(
        r"delete (?:the )?(?:commitment|goal)\s+['\"](.+?)['\"]",
        re.IGNORECASE,
    ),
)


def is_delete_confirmation_reply(message: str) -> bool:
    cleaned = re.sub(r"\s+", " ", str(message or "")).strip()
    return bool(_DELETE_CONFIRMATION_REPLY.fullmatch(cleaned))


def is_delete_rejection_reply(message: str) -> bool:
    cleaned = re.sub(r"\s+", " ", str(message or "")).strip()
    return bool(_DELETE_REJECTION_REPLY.fullmatch(cleaned))


def assistant_prompts_delete(content: str) -> bool:
    lowered = str(content or "").lower()
    if "do you want me to delete" in lowered:
        return True
    if "delete this saved memory" in lowered and "confirm" in lowered:
        return True
    if "just to confirm" in lowered and "delete" in lowered:
        return True
    return False


def extract_delete_target_from_assistant_prompt(content: str) -> str | None:
    for pattern in _DELETE_PROMPT_PATTERNS:
        match = pattern.search(str(content or ""))
        if match is None:
            continue
        target = match.group(1).strip(" .\"'")
        if target:
            return target
    return None


def pending_delete_target_from_history(conversation_history: list[dict]) -> str | None:
    for item in reversed(conversation_history[-8:]):
        if item.get("role") != "assistant":
            continue
        content = str(item.get("content") or "")
        if not assistant_prompts_delete(content):
            continue
        target = extract_delete_target_from_assistant_prompt(content)
        if target:
            return target
    return None


def should_defer_to_delete_confirmation(
    message: str,
    conversation_history: list[dict],
    pending_action: dict | None = None,
) -> bool:
    if not is_delete_confirmation_reply(message):
        normalized = re.sub(r"[^a-z0-9']+", " ", str(message or "").lower())
        normalized = re.sub(r"\s+", " ", normalized).strip()
        if normalized not in {
            "yes",
            "yes please",
            "confirm",
            "confirmed",
            "do it",
            "go ahead",
            "go ahead delete it",
            "delete it",
            "yes delete it",
        }:
            return False
    if isinstance(pending_action, dict):
        action_type = str(pending_action.get("action_type") or "")
        resolver_target = str(
            pending_action.get("resolver_target")
            or pending_action.get("delete_target")
            or ""
        ).strip()
        if action_type == "delete" and resolver_target:
            return True
    return pending_delete_target_from_history(conversation_history) is not None


def response_claims_goal_success(response: str) -> bool:
    text = f" {str(response or '').lower()} "
    return any(
        phrase in text
        for phrase in (
            " goal is set",
            " added as a goal",
            " saved that commitment",
            " next-month goal",
            " added it as a commitment",
            " added it as a goal",
            " setting ",
            " set for the ",
        )
    )

from typing import Any, Optional


DIRECT_SAVE_PATH = "direct_save"
PENDING_CONFIRMATION_PATH = "pending_confirmation"
PENDING_REVIEW_PATH = "pending_review"

DIRECT_SAVE_REASON = "Simple low-risk fact was explicitly confirmed in chat."
PENDING_CONFIRMATION_REASON = (
    "Simple low-risk fact needs user confirmation before durable save."
)


def direct_save_metadata(metadata: Optional[dict[str, Any]]) -> dict[str, Any]:
    return _with_path_metadata(
        metadata,
        memory_path=DIRECT_SAVE_PATH,
        review_required=False,
        decision_reason=DIRECT_SAVE_REASON,
    )


def pending_confirmation_metadata(
    metadata: Optional[dict[str, Any]],
) -> dict[str, Any]:
    return _with_path_metadata(
        metadata,
        memory_path=PENDING_CONFIRMATION_PATH,
        review_required=True,
        decision_reason=PENDING_CONFIRMATION_REASON,
    )


def pending_review_metadata(
    metadata: Optional[dict[str, Any]],
    *,
    candidate_type: str,
    risk_level: str,
    rationale: Optional[str] = None,
) -> dict[str, Any]:
    review_reason = pending_review_reason(
        candidate_type=candidate_type,
        risk_level=risk_level,
    )
    enriched = _with_path_metadata(
        metadata,
        memory_path=PENDING_REVIEW_PATH,
        review_required=True,
        decision_reason=review_reason,
    )
    enriched["candidate_type"] = candidate_type
    enriched["risk_level"] = risk_level
    enriched["review_reason"] = review_reason
    if rationale:
        enriched["review_rationale"] = rationale
    return enriched


def pending_review_reason(*, candidate_type: str, risk_level: str) -> str:
    if candidate_type == "correction":
        return "Correction could change saved memory, so it needs explicit review."
    if candidate_type in {"archive", "merge"}:
        return "This could remove or combine saved memory, so it needs review."
    if candidate_type in {"plan", "plan_milestone"}:
        return "Structured plan memory can affect future guidance, so it needs review."
    if candidate_type in {"entity", "entity_event", "personal_rule", "commitment"}:
        return "Structured memory needs review before changing saved records."
    if candidate_type == "long_term_memory":
        if risk_level == "high":
            return "High-importance extracted memory needs review before saving."
        return "Extracted memory was not explicitly confirmed in chat, so it needs review."
    if risk_level == "high":
        return "High-risk memory change needs explicit review."
    return "Memory change needs review before saving."


def _with_path_metadata(
    metadata: Optional[dict[str, Any]],
    *,
    memory_path: str,
    review_required: bool,
    decision_reason: str,
) -> dict[str, Any]:
    enriched = dict(metadata) if isinstance(metadata, dict) else {}
    enriched["memory_path"] = memory_path
    enriched["review_required"] = review_required
    enriched["decision_reason"] = decision_reason
    return enriched

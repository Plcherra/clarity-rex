from typing import Any, Optional


DIRECT_SAVE_PATH = "direct_save"
DIRECT_SAVE_REASON = "Low-risk fact was saved through Rex's direct memory flow."


def direct_save_metadata(metadata: Optional[dict[str, Any]]) -> dict[str, Any]:
    return _with_path_metadata(
        metadata,
        memory_path=DIRECT_SAVE_PATH,
        review_required=False,
        decision_reason=DIRECT_SAVE_REASON,
    )


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

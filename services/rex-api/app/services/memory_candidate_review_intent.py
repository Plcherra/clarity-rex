import re
from dataclasses import dataclass
from typing import Optional


APPROVE_ALL_PHRASES = {
    "approve all",
    "approve all pending",
    "apply all",
    "apply all pending",
    "confirm all",
    "save all",
    "save all pending",
}
REJECT_ALL_PHRASES = {
    "reject all",
    "reject all pending",
    "discard all",
    "discard all pending",
    "do not save any",
    "dont save any",
}
APPROVE_PHRASES = {
    "yes",
    "yep",
    "yeah",
    "ok",
    "okay",
    "sure",
    "confirm",
    "confirmed",
    "do it",
    "apply",
    "approve",
    "approve it",
    "save it",
    "save that",
    "looks good",
}
VAGUE_APPROVE_PHRASES = {
    "yes",
    "yep",
    "yeah",
    "ok",
    "okay",
    "sure",
}
REJECT_PHRASES = {
    "no",
    "nope",
    "reject",
    "discard",
    "dont save",
    "do not save",
    "cancel",
}
EDIT_PENDING_MEMORY_PATTERN = re.compile(
    r"^edit\s+pending\s+memory\s+([A-Za-z0-9_-]+)\s*:\s*(.+)$",
    re.IGNORECASE | re.DOTALL,
)


@dataclass(frozen=True)
class MemoryCandidateReviewIntent:
    kind: str
    normalized_text: str
    correction_text: Optional[str] = None


class MemoryCandidateReviewIntentClassifier:
    def classify(self, message: str) -> Optional[MemoryCandidateReviewIntent]:
        normalized = normalized_confirmation_text(message)
        if not normalized:
            return None

        correction_text = mixed_correction_text(message)
        if correction_text is not None:
            return MemoryCandidateReviewIntent(
                "approve_with_correction",
                normalized,
                correction_text=correction_text,
            )
        if normalized in APPROVE_ALL_PHRASES or is_natural_approve_all(normalized):
            return MemoryCandidateReviewIntent("approve_all", normalized)
        if normalized in REJECT_ALL_PHRASES or is_natural_reject_all(normalized):
            return MemoryCandidateReviewIntent("reject_all", normalized)
        if EDIT_PENDING_MEMORY_PATTERN.match(message.strip()):
            return MemoryCandidateReviewIntent("edit", normalized)
        if is_pending_review_question(normalized):
            return MemoryCandidateReviewIntent("review", normalized)
        if normalized in REJECT_PHRASES:
            return MemoryCandidateReviewIntent("reject", normalized)
        if normalized.startswith("do not save ") or normalized.startswith("dont save "):
            return MemoryCandidateReviewIntent("reject", normalized)
        if normalized in APPROVE_PHRASES:
            return MemoryCandidateReviewIntent("approve", normalized)
        if normalized.startswith(("confirm ", "confirmed ", "approve ", "apply ")):
            return MemoryCandidateReviewIntent("approve", normalized)
        if normalized.startswith("save ") and "all" not in normalized:
            return MemoryCandidateReviewIntent("approve", normalized)
        return None

    def is_vague_approval(self, message: str) -> bool:
        return normalized_confirmation_text(message) in VAGUE_APPROVE_PHRASES


def is_natural_approve_all(normalized: str) -> bool:
    if not has_group_review_reference(normalized):
        return False
    return any(
        term in normalized
        for term in (
            "finish",
            "complete",
            "confirm",
            "approve",
            "apply",
            "save",
            "done",
            "clear",
        )
    )


def is_natural_reject_all(normalized: str) -> bool:
    if not has_group_review_reference(normalized):
        return False
    has_memory_reference = any(
        term in normalized for term in ("pending", "memory", "memories")
    )
    has_group_reference = any(term in normalized for term in ("all", "those", "these"))
    if not has_memory_reference and not has_group_reference:
        return False
    return any(term in normalized for term in ("reject", "discard", "cancel", "delete"))


def is_pending_review_question(normalized: str) -> bool:
    if not any(term in normalized for term in ("pending", "memory", "memories")):
        return False
    return any(
        term in normalized
        for term in ("why", "review", "list", "show", "what", "which", "status")
    )


def has_group_review_reference(normalized: str) -> bool:
    return any(term in normalized for term in ("all", "those", "these", "them"))


def has_review_session_reference(normalized: str) -> bool:
    return any(term in normalized for term in ("those", "these", "them"))


def mixed_correction_text(message: str) -> Optional[str]:
    normalized = normalized_confirmation_text(message)
    if not normalized.startswith(("yes", "yep", "yeah", "ok", "okay", "sure")):
        return None
    if " but " not in f" {normalized} ":
        return None
    if not any(
        term in normalized
        for term in (" not ", " actually ", " it is ", " its ", " with ", " replace ")
    ):
        return None
    parts = re.split(r"\bbut\b", message, maxsplit=1, flags=re.IGNORECASE)
    correction = parts[-1] if len(parts) > 1 else message
    correction = re.sub(r"\s+", " ", correction).strip()
    return correction or None


def normalized_confirmation_text(message: str) -> str:
    normalized = message.lower().replace("'", "")
    normalized = "".join(
        character if character.isalnum() or character.isspace() else " "
        for character in normalized
    )
    return " ".join(normalized.split())

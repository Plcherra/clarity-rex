"""Keep Grok's conversational reply when the body proposes or applies."""

from __future__ import annotations

from app.services.action_truth_memory import (
    UNEXECUTED_MEMORY_FALLBACK,
    response_claims_saved_memory_success,
)
from app.services.action_truth_thread_mutation import (
    response_claims_thread_or_goal_mutation_success,
)

_SURFACE_KNOWS = "knows"
_SURFACE_GOALS = "goals"

_TRUTH_DENIAL_EXACT = frozenset({UNEXECUTED_MEMORY_FALLBACK})


def _confirm_pending_copy(surface: str) -> str:
    label = "Knows" if surface == _SURFACE_KNOWS else "Goals"
    return (
        f"Got it — I can save that in {label} when you confirm. "
        "Nothing is saved until then."
    )


def _is_truth_denial(text: str) -> bool:
    cleaned = str(text or "").strip()
    if not cleaned:
        return False
    if cleaned in _TRUTH_DENIAL_EXACT:
        return True
    lowered = cleaned.lower()
    return (
        "don't have a confirmed" in lowered
        or "do not have a confirmed" in lowered
    )


def _needs_propose_remap(text: str) -> bool:
    if not text:
        return True
    if text in _TRUTH_DENIAL_EXACT:
        return True
    if response_claims_thread_or_goal_mutation_success(text):
        return True
    if response_claims_saved_memory_success(text):
        return True
    return _is_truth_denial(text)


def continuing_reply_for_propose(
    grok_reply: str,
    *,
    surface_client_cards: bool,
    surface: str = _SURFACE_GOALS,
) -> str:
    """Preserve conversation; never replace it with body-only confirm boilerplate.

    Card mode: Grok text is enough (card is the confirm UI).
    Text mode: append a short say-yes line when missing.
    Surface: Knows vs Goals confirm-pending copy (never Goals for Knows).
    """
    text = str(grok_reply or "").strip()
    # Truth may have already replaced a false claim with an unexecuted
    # fallback; on propose turns use confirm-pending language instead.
    if _needs_propose_remap(text):
        text = _confirm_pending_copy(surface)
    if surface_client_cards:
        return text
    lowered = text.lower()
    if "say yes" in lowered or "nothing is saved until you confirm" in lowered:
        return text
    return (
        f"{text}\n\nSay yes to save — nothing is saved until you confirm."
    )


_CONTINUE_AFTER_APPLY = "What else is on your mind about this?"


def _with_continue(status: str) -> str:
    """Status is fine as the opener; never ship status alone."""
    return f"{status} {_CONTINUE_AFTER_APPLY}"


def continuing_reply_for_apply(grok_reply: str, *, title: str) -> str:
    """Keep Grok's voice after a command apply; note visibility in Goals."""
    text = str(grok_reply or "").strip()
    if not text or _is_truth_denial(text):
        return _with_continue(f"Done — updated in Goals: {title}.")
    if "goals" in text.lower() and (
        "updated" in text.lower() or "saved" in text.lower()
    ):
        return text
    return f"{text}\n\nUpdated in Goals."


def continuing_reply_for_goal_apply(
    grok_reply: str,
    *,
    title: str,
    write_kind: str,
) -> str:
    """Keep Grok's voice after a goal/milestone create/update/delete apply."""
    text = str(grok_reply or "").strip()
    kind = str(write_kind or "").strip()
    if kind == "delete":
        if not text or _is_truth_denial(text):
            return _with_continue(f"Done — deleted from Goals: {title}.")
        lowered = text.lower()
        if "goals" in lowered and "deleted" in lowered:
            return text
        return f"{text}\n\nDeleted from Goals."
    if kind in {"plan", "milestone"}:
        if not text or _is_truth_denial(text):
            return _with_continue(f"Done — saved in Goals: {title}.")
        lowered = text.lower()
        if "goals" in lowered and (
            "saved" in lowered or "updated" in lowered
        ):
            return text
        return f"{text}\n\nSaved in Goals."
    return continuing_reply_for_apply(grok_reply, title=title)


def continuing_reply_for_knows_apply(grok_reply: str, *, title: str) -> str:
    """Keep Grok's voice after a Knows apply."""
    text = str(grok_reply or "").strip()
    if not text or _is_truth_denial(text):
        return _with_continue(f"Done — saved in Knows: {title}.")
    lowered = text.lower()
    if "knows" in lowered and (
        "saved" in lowered or "updated" in lowered or "deleted" in lowered
    ):
        return text
    return f"{text}\n\nSaved in Knows."

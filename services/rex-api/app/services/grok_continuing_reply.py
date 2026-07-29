"""Keep Grok's conversational reply when the body proposes or applies."""

from __future__ import annotations

from app.services.action_truth_thread_mutation import (
    UNEXECUTED_THREAD_OR_GOAL_MUTATION_FALLBACK,
    response_claims_thread_or_goal_mutation_success,
)


def continuing_reply_for_propose(
    grok_reply: str,
    *,
    surface_client_cards: bool,
) -> str:
    """Preserve conversation; never replace it with body-only confirm boilerplate.

    Card mode: Grok text is enough (card is the confirm UI).
    Text mode: append a short say-yes line when missing.
    """
    text = str(grok_reply or "").strip()
    # Truth may have already replaced a false claim with the unexecuted
    # fallback; on propose turns use confirm-pending language instead.
    if (
        not text
        or response_claims_thread_or_goal_mutation_success(text)
        or text == UNEXECUTED_THREAD_OR_GOAL_MUTATION_FALLBACK
    ):
        text = (
            "Got it — I can update that open thread when you confirm. "
            "Nothing is saved until then."
        )
    if surface_client_cards:
        return text
    lowered = text.lower()
    if "say yes" in lowered or "nothing is saved until you confirm" in lowered:
        return text
    return (
        f"{text}\n\nSay yes to save — nothing is saved until you confirm."
    )


def continuing_reply_for_apply(grok_reply: str, *, title: str) -> str:
    """Keep Grok's voice after a command apply; note visibility in Goals."""
    text = str(grok_reply or "").strip()
    if not text:
        return f"Done — updated in Goals: {title}."
    if "goals" in text.lower() and (
        "updated" in text.lower() or "saved" in text.lower()
    ):
        return text
    return f"{text}\n\nUpdated in Goals."


def continuing_reply_for_knows_apply(grok_reply: str, *, title: str) -> str:
    """Keep Grok's voice after a Knows apply."""
    text = str(grok_reply or "").strip()
    if not text:
        return f"Done — saved in Knows: {title}."
    lowered = text.lower()
    if "knows" in lowered and (
        "saved" in lowered or "updated" in lowered or "deleted" in lowered
    ):
        return text
    return f"{text}\n\nSaved in Knows."

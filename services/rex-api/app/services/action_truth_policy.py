ACTION_TRUTH_POLICY_PROMPT = """
Action truth policy:
- Never claim a memory, financial record, goal, budget, or transaction changed unless backend execution metadata confirms success.
- Never say a reminder, calendar event, notification, or external action happened without execution metadata.
- Simple durable facts can be saved directly after Rex acknowledges them.
- Corrections update the existing fact when a matching memory exists.
- Risky or ambiguous action requests should ask one clarifying question instead of pretending a write happened.
""".strip()


UNCONFIRMED_SUCCESS_TERMS = (
    "saved",
    "updated",
    "fixed",
    "changed",
    "deleted",
    "created",
    "moved",
    "sent",
    "categorized",
    "recategorized",
    "noted",
    "remembered",
    "completed",
    "done",
    "all set",
)

CONFIRMATION_TERMS = (
    "confirm",
    "approve",
    "should i",
    "want me to",
    "before i",
    "pending",
    "proposal",
    "would you like me to",
)

OLD_CHAT_SEARCH_CLAIMS = (
    "checked the old chat",
    "checked the old chats",
    "checked old chat",
    "checked old chats",
    "checked all old chats",
    "checked the old conversation",
    "checked the old conversations",
    "checked old conversation",
    "checked old conversations",
    "searched the old chat",
    "searched the old chats",
    "searched old chat",
    "searched old chats",
    "searched all old chats",
    "searched old conversation",
    "searched old conversations",
    "looked through old chat",
    "looked through old chats",
    "looked through all old chats",
    "looked through old conversation",
    "looked through old conversations",
    "looked at old chat",
    "looked at old chats",
    "looked at old conversation",
    "looked at old conversations",
)

NO_OLD_CHAT_RESULT_CLAIMS = (
    "no mentions",
    "no mention",
    "nothing about",
    "don't have any",
    "do not have any",
    "couldn't find",
    "could not find",
    "found nothing",
)


def response_claims_unconfirmed_success(response: str) -> bool:
    """Return True when visible text sounds like a completed durable action."""

    normalized = f" {response.lower()} "
    if any(term in normalized for term in CONFIRMATION_TERMS):
        return False
    return any(term in normalized for term in UNCONFIRMED_SUCCESS_TERMS)


def safe_pending_action_response(
    response: str,
    proposals: list[dict],
) -> str:
    """Remove success wording when the backend only has pending action proposals."""

    cleaned = response.strip()
    if not proposals or not response_claims_unconfirmed_success(cleaned):
        return cleaned

    confirmation_texts = [
        str(proposal.get("confirmation_text") or "").strip()
        for proposal in proposals
        if str(proposal.get("confirmation_text") or "").strip()
    ]
    if confirmation_texts:
        return " ".join(confirmation_texts)
    return "I can prepare that, but I need confirmation before making the change."


def safe_unexecuted_memory_response(response: str) -> str:
    """Block LLM success claims for memory turns without backend write metadata."""

    cleaned = response.strip()
    if not response_claims_unconfirmed_success(cleaned):
        return cleaned
    return (
        "I can help with that, but I don't have a confirmed saved change from this "
        "turn. Tell me the exact fact to save or try again."
    )


def safe_unsupported_action_response(
    response: str,
    unsupported_actions: list[str],
) -> str:
    """Block completion claims for action blocks the backend cannot execute."""

    cleaned = response.strip()
    if not unsupported_actions or not response_claims_unconfirmed_success(cleaned):
        return cleaned
    action = unsupported_actions[0].replace("_", " ")
    return (
        f"I can't complete {action} from Clarity yet. I can help you think it "
        "through or draft it, but I won't claim it was done."
    )


def response_claims_old_chat_search_result(response: str) -> bool:
    normalized = f" {response.lower()} "
    claims_search = any(term in normalized for term in OLD_CHAT_SEARCH_CLAIMS)
    claims_no_result = any(term in normalized for term in NO_OLD_CHAT_RESULT_CLAIMS)
    return claims_search and claims_no_result


def safe_old_chat_search_response(
    response: str,
    *,
    old_chat_evidence_loaded: bool,
) -> str:
    """Avoid pretending old-chat search was exhaustive when no evidence loaded."""

    cleaned = response.strip()
    if old_chat_evidence_loaded:
        return cleaned
    if not response_claims_old_chat_search_result(cleaned):
        return cleaned
    return (
        "I don't see that in saved memory or in the chat evidence retrieved for "
        "this turn. Older chat recall may be incomplete unless that detail was "
        "saved."
    )

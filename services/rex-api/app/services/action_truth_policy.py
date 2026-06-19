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

CHAT_SEARCH_CAPABILITY_LIMIT_CLAIMS = (
    "only search the chat history available right here",
    "only search what's here",
    "only search what is here",
    "only search the current chat",
    "only search this chat",
    "just what's here",
    "just what is here",
    "older messages might not show up",
    "older parts don't show up",
    "older parts do not show up",
    "older ones stay hidden",
    "search only pulls from the chats here",
    "search only pulls from chats here",
)

UNSUPPORTED_DENIAL_TERMS = (
    "can't",
    "cannot",
    "can't complete",
    "cannot complete",
    "can't do",
    "cannot do",
    "not supported",
    "not available",
    "cannot yet",
    "can't yet",
)

DEGRADED_MEMORY_NO_RESULT_CLAIMS = (
    "i don't know",
    "i do not know",
    "i don't have anything",
    "i do not have anything",
    "i don't have any",
    "i do not have any",
    "nothing about",
    "no information",
    "no mention",
    "no mentions",
    "no saved memory",
    "no memory",
    "no memories",
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
    if not unsupported_actions:
        return cleaned
    normalized = f" {cleaned.lower()} "
    if not response_claims_unconfirmed_success(cleaned) and any(
        term in normalized for term in UNSUPPORTED_DENIAL_TERMS
    ):
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
    chat_search_results_loaded: bool,
    memory_status: object = None,
) -> str:
    """Avoid pretending old-chat search was exhaustive when no results loaded."""

    cleaned = response.strip()
    if chat_search_results_loaded:
        return cleaned
    if not response_claims_old_chat_search_result(cleaned):
        return cleaned
    if chat_search_completed_without_results(memory_status):
        return cleaned
    return (
        "I don't have a reliable chat search result for that right now. I can't "
        "confidently say it was never mentioned unless chat search completes."
    )


def safe_empty_recall_search_response(
    response: str,
    *,
    memory_status: object = None,
) -> str:
    """Use one calm no-results answer after a complete empty recall search."""

    cleaned = response.strip()
    if not chat_search_completed_without_results(memory_status):
        return cleaned
    if not response_claims_no_memory_result(cleaned):
        return cleaned
    return (
        "I searched my saved memory and old chats but couldn't find anything "
        "about that."
    )


def response_claims_limited_chat_search_capability(response: str) -> bool:
    normalized = f" {response.lower()} "
    return any(term in normalized for term in CHAT_SEARCH_CAPABILITY_LIMIT_CLAIMS)


def safe_chat_search_capability_response(response: str) -> str:
    """Block false claims that Rex can only search the visible/current chat."""

    cleaned = response.strip()
    if not response_claims_limited_chat_search_capability(cleaned):
        return cleaned
    return (
        "I should be able to search across your saved chat history, not only this "
        "current chat. If a search does not return results, that means the chat "
        "search path needs fixing or the source is unavailable; it is not a limit "
        "you can fix from your side."
    )


def chat_search_completed_without_results(memory_status: object) -> bool:
    if not isinstance(memory_status, dict):
        return False
    if memory_status_is_degraded(memory_status):
        return False
    statuses = memory_status.get("source_statuses")
    if not isinstance(statuses, list):
        return False
    for status in statuses:
        if not isinstance(status, dict):
            continue
        if status.get("source") != "chat_search":
            continue
        return (
            status.get("attempted") is True
            and status.get("succeeded") is True
            and status.get("partial") is not True
            and int(status.get("result_count") or 0) == 0
        )
    return False


def memory_status_is_degraded(memory_status: object) -> bool:
    if not isinstance(memory_status, dict):
        return False
    return str(memory_status.get("state") or "").strip().lower() == "degraded"


def response_claims_no_memory_result(response: str) -> bool:
    normalized = f" {response.lower()} "
    return any(term in normalized for term in DEGRADED_MEMORY_NO_RESULT_CLAIMS)


def safe_degraded_memory_search_response(
    response: str,
    *,
    memory_status: object,
) -> str:
    """Avoid turning degraded memory/search context into a false no-results claim."""

    cleaned = response.strip()
    if not memory_status_is_degraded(memory_status):
        return cleaned
    if not response_claims_no_memory_result(cleaned):
        return cleaned
    return (
        "Memory search is temporarily unavailable right now. I can't confidently "
        "say what I remember until it's working again."
    )

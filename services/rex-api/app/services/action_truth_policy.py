ACTION_TRUTH_POLICY_PROMPT = "\n".join([
    "Action truth policy:",
    "- Never claim durable changes without backend success metadata.",
    "- If recall search is degraded, say it is unavailable.",
    "- If recall search completed empty, use the standard no-results answer.",
    "- Do not claim Rex can only search the current visible chat.",
])

DEGRADED_RECALL_FALLBACK = (
    "Memory search is temporarily unavailable right now. I can't confidently "
    "say what I remember until it's working again."
)
EMPTY_RECALL_FALLBACK = (
    "I searched my saved memory and old chats but couldn't find anything about that."
)
CHAT_SEARCH_CAPABILITY_FALLBACK = (
    "I can search saved chat history when chat search is available. I won't treat "
    "this visible chat as the only source."
)
UNEXECUTED_DELETE_FALLBACK = (
    "I can help delete saved memory, but I don't have a confirmed backend delete "
    "from this turn. Tell me the exact saved item to delete and I'll ask for "
    "confirmation before changing it."
)

_SUCCESS_TERMS = tuple(
    "saved|updated|fixed|changed|deleted|created|moved|sent|categorized|"
    "recategorized|noted|remembered|completed|done|all set".split("|")
)
_CONFIRMATION_TERMS = tuple(
    "confirm|approve|should i|want me to|before i|pending|proposal|"
    "would you like me to".split("|")
)
_UNSUPPORTED_DENIAL_TERMS = tuple(
    "can't|cannot|can't complete|cannot complete|can't do|cannot do|"
    "not supported|not available|cannot yet|can't yet".split("|")
)
_NO_RESULT_TERMS = tuple(
    "i don't know|i do not know|i don't have anything|i do not have anything|"
    "i don't have any|i do not have any|nothing about|no information|"
    "no mention|no mentions|no saved memory|no memory|no memories|"
    "couldn't find|could not find|found nothing".split("|")
)
_SEARCH_TERMS = ("search", "searched", "check", "checked", "looked")
_DELETE_REQUEST_TERMS = tuple(
    "delete|remove|archive|drop|forget|erase|get rid of".split("|")
)
_CHAT_HISTORY_TERMS = tuple("old chat|old chats|chat history|chats|conversation|conversations".split("|"))
_LIMITATION_TERMS = tuple(
    "only search the chat history available right here|only search what's here|"
    "only search what is here|only search the current chat|only search this chat|"
    "older messages might not show up|older parts don't show up|"
    "older parts do not show up|older ones stay hidden|"
    "search only pulls from the chats here|search only pulls from chats here".split("|")
)
def _normalized(response: str) -> str: return f" {response.lower()} "
def _contains_any(text: str, terms: tuple[str, ...]) -> bool: return any(term in text for term in terms)
def _chat_search_statuses(memory_status: object) -> list[dict]:
    if not isinstance(memory_status, dict):
        return []
    statuses = memory_status.get("source_statuses") or []
    return [
        status for status in statuses
        if isinstance(status, dict) and status.get("source") == "chat_search"
    ]
def response_claims_unconfirmed_success(response: str) -> bool:
    text = _normalized(response)
    return not _contains_any(text, _CONFIRMATION_TERMS) and _contains_any(text, _SUCCESS_TERMS)
def response_claims_no_memory_result(response: str) -> bool: return _contains_any(_normalized(response), _NO_RESULT_TERMS)
def response_claims_old_chat_search_result(response: str) -> bool:
    text = _normalized(response)
    return response_claims_no_memory_result(response) and _contains_any(text, _SEARCH_TERMS) and _contains_any(text, _CHAT_HISTORY_TERMS)
def response_claims_limited_chat_search_capability(response: str) -> bool: return _contains_any(_normalized(response), _LIMITATION_TERMS)
def request_asks_delete(message: str) -> bool: return _contains_any(_normalized(message), _DELETE_REQUEST_TERMS)
def memory_status_is_degraded(memory_status: object) -> bool:
    if not isinstance(memory_status, dict):
        return False
    state = str(memory_status.get("state") or "").strip().lower()
    return state == "degraded" or any(status.get("partial") is True for status in _chat_search_statuses(memory_status))
def chat_search_completed_without_results(memory_status: object) -> bool:
    if not isinstance(memory_status, dict) or memory_status_is_degraded(memory_status):
        return False
    return any(status.get("attempted") is True and status.get("succeeded") is True
               and int(status.get("result_count") or 0) == 0
               for status in _chat_search_statuses(memory_status))
def safe_pending_action_response(response: str, proposals: list[dict]) -> str:
    cleaned = response.strip()
    if not proposals or not response_claims_unconfirmed_success(cleaned):
        return cleaned
    confirmations = [
        str(proposal.get("confirmation_text") or "").strip()
        for proposal in proposals
        if str(proposal.get("confirmation_text") or "").strip()
    ]
    return (
        " ".join(confirmations)
        if confirmations
        else "I can prepare that, but I need confirmation before making the change."
    )
def safe_unexecuted_memory_response(response: str) -> str:
    cleaned = response.strip()
    if not response_claims_unconfirmed_success(cleaned):
        return cleaned
    return (
        "I can help with that, but I don't have a confirmed saved change from this "
        "turn. Tell me the exact fact to save or try again."
    )
def safe_unexecuted_delete_response(response: str, *, user_message: str) -> str:
    cleaned = response.strip()
    if not request_asks_delete(user_message):
        return cleaned
    if not response_claims_unconfirmed_success(cleaned):
        return cleaned
    return UNEXECUTED_DELETE_FALLBACK
def safe_unsupported_action_response(response: str, unsupported_actions: list[str]) -> str:
    cleaned = response.strip()
    if not unsupported_actions:
        return cleaned
    text = _normalized(cleaned)
    if (
        not response_claims_unconfirmed_success(cleaned)
        and _contains_any(text, _UNSUPPORTED_DENIAL_TERMS)
    ):
        return cleaned
    action = unsupported_actions[0].replace("_", " ")
    return (
        f"I can't complete {action} from Clarity yet. I can help you think it "
        "through or draft it, but I won't claim it was done."
    )
def safe_degraded_memory_search_response(response: str, *, memory_status: object) -> str:
    cleaned = response.strip()
    return DEGRADED_RECALL_FALLBACK if memory_status_is_degraded(memory_status) and response_claims_no_memory_result(cleaned) else cleaned
def safe_old_chat_search_response(
    response: str, *, chat_search_results_loaded: bool, memory_status: object = None,
) -> str:
    cleaned = response.strip()
    if chat_search_results_loaded or not response_claims_old_chat_search_result(cleaned):
        return cleaned
    return cleaned if chat_search_completed_without_results(memory_status) else DEGRADED_RECALL_FALLBACK
def safe_empty_recall_search_response(response: str, *, memory_status: object = None) -> str:
    cleaned = response.strip()
    return EMPTY_RECALL_FALLBACK if chat_search_completed_without_results(memory_status) and response_claims_no_memory_result(cleaned) else cleaned
def safe_chat_search_capability_response(response: str) -> str:
    cleaned = response.strip()
    return (
        CHAT_SEARCH_CAPABILITY_FALLBACK
        if response_claims_limited_chat_search_capability(cleaned)
        else cleaned
    )

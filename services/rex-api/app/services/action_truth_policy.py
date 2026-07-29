import re

ACTION_TRUTH_POLICY_PROMPT = "\n".join([
    "Action truth policy:",
    "- Never claim durable changes without backend success metadata.",
    (
        "- If recall search has an issue, say the search had trouble and ask "
        "for a retry."
    ),
    "- If recall search completed empty, use the standard no-results answer.",
    "- Do not claim Rex can only search the current visible chat.",
])

DEGRADED_RECALL_FALLBACK = (
    "I tried to search saved memory and old chats, but the search had trouble. "
    "Try again with a keyword or phrase and I'll search broadly."
)
EMPTY_RECALL_FALLBACK = (
    "I searched my saved memory and old chats but couldn't find anything about that."
)
FILTERED_RECALL_FALLBACK = (
    "I searched saved memory and old chats, but the only possible chat matches "
    "were search echoes or unusable no-result messages. I don't have usable "
    "chat-history evidence for that yet."
)
PARTIAL_RECALL_FALLBACK = (
    "I found related chat history, not saved memory, but I don't have enough "
    "clear evidence in the retrieved context to answer that confidently."
)
CHAT_SEARCH_CAPABILITY_FALLBACK = (
    "I can search saved chat history when chat search is available. I won't treat "
    "this visible chat as the only source."
)
_CANONICAL_TRUTH_FALLBACKS = frozenset(
    {
        DEGRADED_RECALL_FALLBACK,
        EMPTY_RECALL_FALLBACK,
        FILTERED_RECALL_FALLBACK,
        PARTIAL_RECALL_FALLBACK,
        CHAT_SEARCH_CAPABILITY_FALLBACK,
    }
)
UNEXECUTED_DELETE_FALLBACK = (
    "I can help delete saved memory, but I don't have a confirmed backend delete "
    "from this turn. Tell me the exact saved item to delete and I'll ask for "
    "confirmation before changing it."
)
UNEXECUTED_GOAL_FALLBACK = (
    "I can help save that as a goal, but I don't have a confirmed backend save "
    "from this turn. Tell me the exact goal again and I'll save it directly."
)
UNEXECUTED_FINANCE_FALLBACK = (
    "I can help change transactions or budgets, but I don't have a confirmed "
    "change from this turn. Tell me exactly what to change and I'll ask for "
    "confirmation before applying it."
)
_FINANCE_WRITE_TERMS = (
    "recategor",
    "re-categor",
    "recategorize",
    "re categorize",
    "change category",
    "move to",
    "move it to",
    "move that to",
    "put it in",
    "put that in",
    "switch to",
    "set category",
    "update category",
    "rename category",
    "create budget",
    "set budget",
    "update budget",
    "change budget",
    "delete budget",
    "new budget",
    "budget to",
)

_SUCCESS_TERMS = tuple(
    "saved|saving|i'll save|i will save|"
    "i'll update|i will update|i'll change|i will change|"
    "updated|updating|fixed|fixing|changed|changing|deleted|deleting|"
    "created|creating|moved|moving|sent|sending|categorized|categorizing|"
    "recategorized|recategorizing|noted|noting|remembered|remembering|"
    "completed|done|all set|"
    "guardé|guarde|guardado|actualicé|actualice|actualizado|"
    "sauvegardé|enregistré|souviens|"
    "gespeichert|aktualisiert".split("|")
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
def _is_canonical_truth_fallback(response: str) -> bool:
    return response.strip() in _CANONICAL_TRUTH_FALLBACKS
def _chat_search_statuses(memory_status: object) -> list[dict]:
    if not isinstance(memory_status, dict):
        return []
    statuses = memory_status.get("source_statuses") or []
    return [
        status for status in statuses
        if isinstance(status, dict) and status.get("source") == "chat_search"
    ]
def response_claims_unconfirmed_success(response: str) -> bool:
    cleaned = response.strip()
    if _is_canonical_truth_fallback(cleaned):
        return False
    text = _normalized(cleaned)
    return not _contains_any(text, _CONFIRMATION_TERMS) and _contains_any(text, _SUCCESS_TERMS)


def response_claims_no_memory_result(response: str) -> bool: return _contains_any(_normalized(response), _NO_RESULT_TERMS)
def response_claims_old_chat_search_result(response: str) -> bool:
    text = _normalized(response)
    return response_claims_no_memory_result(response) and _contains_any(text, _CHAT_HISTORY_TERMS)
def response_claims_limited_chat_search_capability(response: str) -> bool: return _contains_any(_normalized(response), _LIMITATION_TERMS)
def request_asks_delete(message: str) -> bool: return _contains_any(_normalized(message), _DELETE_REQUEST_TERMS)
def request_asks_finance_write(message: str) -> bool:
    text = _normalized(message)
    if _contains_any(text, _FINANCE_WRITE_TERMS):
        return True
    if "budget" in text and _contains_any(
        text,
        (
            " create ",
            " set ",
            " update ",
            " change ",
            " delete ",
            " raise ",
            " lower ",
            " increase ",
            " decrease ",
        ),
    ):
        return True
    if "categor" in text and _contains_any(
        text,
        (" move ", " change ", " update ", " set ", " put "),
    ):
        return True
    if re.search(r"\bmove\b.+\bto\b", text):
        return True
    return False
def memory_status_is_degraded(memory_status: object) -> bool:
    if not isinstance(memory_status, dict):
        return False
    state = str(memory_status.get("state") or "").strip().lower()
    return state == "degraded" or any(
        status.get("partial") is True
        for status in _chat_search_statuses(memory_status)
    )


def memory_status_has_saved_knowledge(memory_status: object) -> bool:
    if not isinstance(memory_status, dict):
        return False
    return int(memory_status.get("saved_knowledge_count") or 0) > 0


def chat_search_completed_without_results(memory_status: object) -> bool:
    if (
        not isinstance(memory_status, dict)
        or memory_status_is_degraded(memory_status)
        or memory_status_has_saved_knowledge(memory_status)
    ):
        return False
    return any(
        status.get("attempted") is True
        and status.get("succeeded") is True
        and status.get("status") == "empty"
        and status.get("filtered_all_matches") is not True
        and int(status.get("result_count") or 0) == 0
        for status in _chat_search_statuses(memory_status)
    )
def chat_search_filtered_without_results(memory_status: object) -> bool:
    if (
        not isinstance(memory_status, dict)
        or memory_status_is_degraded(memory_status)
        or memory_status_has_saved_knowledge(memory_status)
    ):
        return False
    return any(
        status.get("attempted") is True
        and status.get("succeeded") is True
        and status.get("status") == "filtered"
        and status.get("filtered_all_matches") is True
        and int(status.get("result_count") or 0) == 0
        for status in _chat_search_statuses(memory_status)
    )
def safe_pending_action_response(response: str, proposals: list[dict]) -> str:
    cleaned = response.strip()
    if not proposals or not response_claims_unconfirmed_success(cleaned):
        return cleaned
    confirmations = [
        str(proposal.get("confirmation_text") or "").strip()
        for proposal in proposals
        if str(proposal.get("confirmation_text") or "").strip()
    ]
    if confirmations:
        return (
            " ".join(confirmations)
            + " Tap confirm to save — nothing is saved until you confirm."
        )
    return (
        "I can prepare that, but nothing is saved until you tap confirm."
    )
def safe_unexecuted_delete_response(
    response: str,
    *,
    user_message: str,
    conversation_history: list[dict] | None = None,
    intent: str | None = None,
) -> str:
    from app.services.memory_delete_reference import (
        is_delete_clarification_message,
        response_claims_delete_success,
    )
    from app.services.body_display_text import is_goals_inventory_query

    cleaned = response.strip()
    if is_goals_inventory_query(user_message):
        return cleaned
    should_guard = request_asks_delete(user_message) or is_delete_clarification_message(
        user_message,
        conversation_history,
    )
    if intent == "finance":
        should_guard = should_guard and request_asks_delete(user_message)
    if intent == "goal" and not request_asks_delete(user_message):
        should_guard = False
    if not should_guard:
        return cleaned
    if response_claims_delete_success(cleaned) or response_claims_unconfirmed_success(
        cleaned
    ):
        return UNEXECUTED_DELETE_FALLBACK
    return cleaned


def safe_unexecuted_finance_response(
    response: str,
    *,
    user_message: str = "",
    intent: str | None = None,
) -> str:
    cleaned = response.strip()
    if intent is not None and intent not in {"finance", "unknown"}:
        return cleaned
    if not request_asks_finance_write(user_message):
        return cleaned
    if not response_claims_unconfirmed_success(cleaned):
        return cleaned
    return UNEXECUTED_FINANCE_FALLBACK


def safe_unexecuted_goal_response(
    response: str,
    *,
    user_message: str = "",
    intent: str | None = None,
) -> str:
    from app.services.memory_delete_reference import response_claims_goal_success
    from app.services.body_display_text import is_goals_inventory_query

    cleaned = response.strip()
    if is_goals_inventory_query(user_message):
        return cleaned
    if intent is not None and intent not in {"goal", "unknown"}:
        return cleaned
    if not response_claims_goal_success(cleaned):
        return cleaned
    if not response_claims_unconfirmed_success(cleaned):
        return cleaned
    return UNEXECUTED_GOAL_FALLBACK
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
    if (
        memory_status_is_degraded(memory_status)
        and not memory_status_has_saved_knowledge(memory_status)
        and response_claims_no_memory_result(cleaned)
    ):
        return DEGRADED_RECALL_FALLBACK
    return cleaned
def safe_old_chat_search_response(
    response: str, *, chat_search_results_loaded: bool, memory_status: object = None,
) -> str:
    cleaned = response.strip()
    if not response_claims_old_chat_search_result(cleaned):
        return cleaned
    if chat_search_results_loaded:
        return PARTIAL_RECALL_FALLBACK
    if memory_status_has_saved_knowledge(memory_status):
        return cleaned
    if chat_search_filtered_without_results(memory_status):
        return FILTERED_RECALL_FALLBACK
    return cleaned if chat_search_completed_without_results(memory_status) else DEGRADED_RECALL_FALLBACK
def safe_empty_recall_search_response(response: str, *, memory_status: object = None) -> str:
    cleaned = response.strip()
    if (
        chat_search_filtered_without_results(memory_status)
        and response_claims_no_memory_result(cleaned)
    ):
        return FILTERED_RECALL_FALLBACK
    return EMPTY_RECALL_FALLBACK if chat_search_completed_without_results(memory_status) and response_claims_no_memory_result(cleaned) else cleaned
def safe_chat_search_capability_response(response: str) -> str:
    cleaned = response.strip()
    return (
        CHAT_SEARCH_CAPABILITY_FALLBACK
        if response_claims_limited_chat_search_capability(cleaned)
        else cleaned
    )

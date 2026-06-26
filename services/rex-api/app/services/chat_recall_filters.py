from app.services.chat_search_scoring import ChatSearchScorer


CHAT_SEARCH_SCORER = ChatSearchScorer()


MEMORY_REJECTION_MARKERS = (
    "do not remember",
    "do not save",
    "don't remember",
    "don't save",
    "dont remember",
    "dont save",
    "no problem. i won't save that",
    "no problem. i will not save that",
    "won't save that",
    "will not save that",
)
CHAT_SEARCH_NO_RESULT_MARKERS = (
    "do not have anything saved",
    "don't have anything saved",
    "do not have any info",
    "don't have any info",
    "do not have your",
    "don't have your",
    "nothing about",
    "nothing came up",
    "nothing showed up",
    "found nothing",
    "could not find",
    "couldn't find",
    "did not find",
    "didn't find",
    "no mentions",
    "no mention",
)


def is_memory_rejection_message(message: dict) -> bool:
    content = str(message.get("content") or "").strip().lower()
    if not content:
        return False
    return any(marker in content for marker in MEMORY_REJECTION_MARKERS)


def is_chat_search_no_result_message(message: dict) -> bool:
    content = str(message.get("content") or "").strip().lower()
    if not content:
        return False
    return any(marker in content for marker in CHAT_SEARCH_NO_RESULT_MARKERS)


def is_recall_question_user_content(content: str) -> bool:
    normalized = str(content or "").strip().lower()
    if not normalized:
        return False
    if CHAT_SEARCH_SCORER.is_search_question_text(normalized):
        return True
    return any(
        marker in normalized
        for marker in (
            "do you know",
            "do you remember",
            "can you search",
            "search old",
            "search the old",
            "search into",
            "check old",
            "check the old",
            "look into the chats",
            "looked through",
            "double checked",
            "double-checked",
            "pretty sure",
            "have access to the chat",
            "are you sure",
            "sent you the",
            "i thought i said",
            "i told you",
        )
    )


def is_chat_search_user_content_message(message: dict) -> bool:
    if str(message.get("role") or "") != "user":
        return False
    content = str(message.get("content") or "").strip().lower()
    if not content or is_chat_search_no_result_message(message):
        return False
    if is_memory_rejection_message(message):
        return False
    if is_recall_question_user_content(content):
        return False
    return True


def chat_search_candidate_rank(message: dict) -> tuple[int, str]:
    if is_chat_search_user_content_message(message):
        priority = 0
    elif str(message.get("role") or "") == "assistant":
        priority = 1
    else:
        priority = 2
    timestamp = str(message.get("timestamp") or "")
    score = float(message.get("_chat_search_score") or 0)
    return (priority, f"{9999 - score:09.4f}", timestamp)

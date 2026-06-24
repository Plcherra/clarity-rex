from typing import Optional


def message_from_ranked_search_row(row: dict) -> Optional[dict]:
    message_id = str(row.get("message_id") or "").strip()
    if not message_id:
        return None
    return {
        "id": message_id,
        "conversation_id": row.get("conversation_id"),
        "role": row.get("role") or "message",
        "content": row.get("content") or "",
        "timestamp": row.get("message_timestamp"),
        "relevance_score": float(row.get("rank") or 0),
        "search_reason": row.get("search_reason") or "indexed chat search match",
        "matched_terms": list(row.get("matched_terms") or []),
    }


def conversation_result_from_ranked_row(row: dict) -> dict:
    message = message_from_ranked_search_row(row)
    match_type = str(row.get("match_type") or "message")
    preview = str(
        row.get("content")
        or row.get("conversation_title")
        or "Matched conversation."
    ).strip()
    return {
        "conversation_id": row.get("conversation_id"),
        "conversation_title": row.get("conversation_title"),
        "conversation_timestamp": row.get("conversation_timestamp"),
        "message": message,
        "match_type": match_type,
        "preview": preview,
        "relevance_score": float(row.get("rank") or 0),
        "search_reason": row.get("search_reason") or "indexed chat search match",
        "matched_terms": list(row.get("matched_terms") or []),
    }


def conversation_result_from_semantic_row(row: dict) -> dict:
    message = message_from_ranked_search_row(row)
    match_type = str(row.get("match_type") or "semantic_message")
    preview = str(
        row.get("content")
        or row.get("conversation_title")
        or "Matched conversation."
    ).strip()
    return {
        "conversation_id": row.get("conversation_id"),
        "conversation_title": row.get("conversation_title"),
        "conversation_timestamp": row.get("conversation_timestamp"),
        "message": message,
        "match_type": match_type,
        "preview": preview,
        "relevance_score": float(row.get("rank") or 0),
        "search_reason": row.get("search_reason") or "semantic chat search match",
        "matched_terms": list(row.get("matched_terms") or []),
    }

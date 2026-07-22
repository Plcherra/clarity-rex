"""Format thin open-thread context for Grok without dumping full records."""

from __future__ import annotations

from typing import Any

OPEN_THREADS_PROMPT_PREFIX = (
    "Open threads (id + title + short summary; user opted in; not saved memory):\n"
)


def format_open_threads_context(threads: list[dict[str, Any]]) -> str | None:
    active = [
        thread
        for thread in threads
        if str(thread.get("status") or "") == "active"
    ]
    if not active:
        return None

    lines = [OPEN_THREADS_PROMPT_PREFIX.strip()]
    for thread in active[:5]:
        title = str(thread.get("title") or "").strip()
        thread_id = str(thread.get("id") or "").strip()
        summary = _summary_snippet(thread.get("summary"))
        if not title:
            continue
        details = f" | summary: {summary}" if summary else ""
        if thread_id:
            lines.append(f"- {thread_id}: {title}{details}")
        else:
            lines.append(f"- {title}{details}")

    if len(lines) <= 1:
        return None
    lines.append(
        "Prefer update_open_thread with the listed id when changing an existing "
        "habit/thread. Match existing threads by id, title, time, or summary "
        "before creating a new one. Include summary when the user gives the "
        "reminder details or why it matters. Never invent threads not listed here."
    )
    return "\n".join(lines)


def _summary_snippet(value: Any) -> str:
    text = str(value or "").strip()
    if not text:
        return ""
    if len(text) <= 80:
        return text
    return f"{text[:77].rstrip()}..."

"""Format active open thread titles + ids for thin base turns (no summaries dump)."""

from __future__ import annotations

from typing import Any

OPEN_THREADS_PROMPT_PREFIX = (
    "Open threads (id + title; user opted in; not saved memory):\n"
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
        if not title:
            continue
        if thread_id:
            lines.append(f"- {thread_id}: {title}")
        else:
            lines.append(f"- {title}")

    if len(lines) <= 1:
        return None
    lines.append(
        "Prefer update_open_thread with the listed id when changing an existing "
        "habit/thread. Use create_open_thread only for a new one. "
        "Never invent threads not listed here."
    )
    return "\n".join(lines)

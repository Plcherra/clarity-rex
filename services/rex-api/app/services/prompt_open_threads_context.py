"""Format active open thread titles for thin base turns (no summaries dump)."""

from __future__ import annotations

from typing import Any

OPEN_THREADS_PROMPT_PREFIX = (
    "Open threads (titles only; user opted in; not saved memory):\n"
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
        if not title:
            continue
        lines.append(f"- {title}")

    if len(lines) <= 1:
        return None
    lines.append(
        "Reference at most one thread naturally when it fits. "
        "Never invent threads not listed here."
    )
    return "\n".join(lines)

"""Format active open threads for Rex prompt context."""

from __future__ import annotations

from typing import Any

OPEN_THREADS_PROMPT_PREFIX = (
    "Open threads (user opted in; not saved memory):\n"
    "These are companion follow-ups the user consented to. "
    "They are NOT saved memory and NOT chat history.\n"
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
        summary = str(thread.get("summary") or "").strip()
        line = f"- open thread: {title}"
        if summary and summary != title:
            line = f"{line} — {summary}"
        lines.append(line)

    if len(lines) <= 1:
        return None
    lines.append(
        "You may reference at most one thread naturally when it fits. "
        "Ask a light follow-up only when appropriate. "
        "Never invent threads not listed here."
    )
    return "\n".join(lines)

"""Shared Clarity vocabulary for goals, saved memory, and chat history."""

from __future__ import annotations

GOAL_SINGULAR = "goal"
GOAL_PLURAL = "goals"
SAVED_MEMORY_SINGULAR = "saved memory"
SAVED_MEMORY_PLURAL = "saved memories"
CHAT_HISTORY_LABEL = "chat history"

CLARITY_KNOWLEDGE_LANGUAGE_PROMPT = (
    "Clarity vocabulary (use consistently):\n"
    "- Goal: a longer-term plan tracked in Clarity Goals.\n"
    "- Saved memory: an explicit fact saved to What Clarity Knows.\n"
    "- Chat history: searchable past messages; not saved memory unless the user "
    "explicitly saved it.\n"
    "Do not call goals 'saved memory'. Do not call chat search "
    "results 'saved memory'."
)


def goal_saved_message(title: str) -> str:
    return f"Got it, I added this as a {GOAL_SINGULAR}: {title}."


def goals_saved_message(*, count: int, titles: str) -> str:
    label = GOAL_SINGULAR if count == 1 else GOAL_PLURAL
    if count == 1:
        return f"Got it, I added this as a {label}: {titles}."
    return f"Got it, I added {count} {label}: {titles}."


def reclassified_from_memory_message(
    *,
    title: str,
    total: int = 1,
    titles: str | None = None,
) -> str:
    if total > 1 and titles:
        return (
            f"Got it, I removed that from {SAVED_MEMORY_SINGULAR} and added "
            f"{total} {GOAL_PLURAL}: {titles}."
        )
    return (
        f"Got it, I removed that from {SAVED_MEMORY_SINGULAR} and added it as a "
        f"{GOAL_SINGULAR}: {title}."
    )


def reclassified_without_memory_message(
    *,
    title: str,
    total: int = 1,
    titles: str | None = None,
) -> str:
    if total > 1 and titles:
        return f"Got it, I added {total} {GOAL_PLURAL}: {titles}."
    return f"Got it, I added that as a {GOAL_SINGULAR}: {title}."

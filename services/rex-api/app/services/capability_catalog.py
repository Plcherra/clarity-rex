"""Frozen capability names for the tiny system prompt (plan 05)."""

from __future__ import annotations

# Names only — no manuals. Body handlers land in later phases.
CAPABILITY_NAMES: tuple[str, ...] = (
    "just_chat",
    "unsupported",
    "save_memory",
    "update_memory",
    "delete_knows_item",
    "save_person",
    "update_person_state",
    "add_person_note",
    "save_connection",
    "save_shared_history",
    "fetch_person_context",
    "search_chats",
    "list_knows_summary",
    "create_goal",
    "update_goal",
    "delete_goal",
    "create_milestone",
    "update_milestone",
    "delete_milestone",
    "create_open_thread",
    "update_open_thread",
    "delete_open_thread",
    "fetch_spend_insight",
    "fetch_account_summary",
    "categorize_transaction",
    "bulk_categorize",
    "create_category",
    "update_category",
    "delete_category",
    "create_budget",
    "update_budget",
    "delete_budget",
)


def capability_names_prompt() -> str:
    lines = ", ".join(CAPABILITY_NAMES)
    return (
        "Capability names (body executes after Auto Suggestions gate):\n"
        f"{lines}\n"
        "Unsupported examples: send_email, send_sms, external_world_actions.\n"
        "Never claim email, SMS, or other external-world actions were done."
    )

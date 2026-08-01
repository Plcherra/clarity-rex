"""Frozen capability names — the enum on the rex_action tool (plan 05)."""

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
    # save_connection / save_shared_history / fetch_person_context: Phase H.
    # A name here is a promise the body keeps, so they stay out until the
    # Knows UI can show what they would write.
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
    # delete_open_thread: not body-wired in Phase C — close threads in Goals.
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

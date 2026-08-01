"""The one function Grok may call to make the body do something (plan 05).

Actions used to be a ```rex_action``` fence appended after the prose, which put
the instruction to the body at the end of a reply that a token cap could cut
off — Rex would say "adding this goal" and the goal would never arrive. Invalid
JSON failed the same silent way.

A tool call is returned by the API as its own field, so it cannot be truncated
away by long prose and cannot be malformed. One function rather than one per
capability keeps the schema small: the catalog is already the list of names,
and repeating it as 28 signatures would cost more than the prose it replaces.
"""

from __future__ import annotations

from typing import Any

from app.services.capability_catalog import CAPABILITY_NAMES

TOOL_NAME = "rex_action"


def capability_tools() -> list[dict[str, Any]]:
    """The tool list sent with every turn."""
    return [
        {
            "type": "function",
            "function": {
                "name": TOOL_NAME,
                "description": (
                    "Make Clarity do something. Call once per action, in the "
                    "same turn as your reply. Talking about an action does not "
                    "perform it."
                ),
                "parameters": {
                    "type": "object",
                    "properties": {
                        "action": {
                            "type": "string",
                            "enum": list(CAPABILITY_NAMES),
                        },
                        "payload": {
                            "type": "object",
                            "description": (
                                "Fields for this action, e.g. title, summary, "
                                "content, query, category, thread_id, plan_id."
                            ),
                            "additionalProperties": True,
                        },
                        "auto": {
                            "type": "boolean",
                            "description": (
                                "True only when this is your own offer rather "
                                "than something the user asked for."
                            ),
                        },
                        "explicit": {
                            "type": "boolean",
                            "description": "True when the user asked for this now.",
                        },
                        "capability_hint": {
                            "type": "string",
                            "description": "For unsupported: what was asked for.",
                        },
                    },
                    "required": ["action"],
                },
            },
        }
    ]

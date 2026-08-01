"""What Grok is actually told on a turn: system prompt plus the tool schema.

Capability names left the prompt when actions became tool calls — the enum on
rex_action is the list now. A test asking "is Rex told it can do X" has to look
at both halves, and a size budget has to count both too.
"""

from __future__ import annotations

import json

from app.services.capability_tools import capability_tools


def tool_schema_json() -> str:
    return json.dumps(capability_tools())


def capability_surface(prompt: str = "") -> str:
    return f"{prompt}\n{tool_schema_json()}"

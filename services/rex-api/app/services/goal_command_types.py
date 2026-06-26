from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Protocol


class GoalCommandStore(Protocol):
    async def save_message(self, conversation_id: str, role: str, content: str) -> dict:
        pass

    async def get_recent_messages(
        self,
        conversation_id: str,
        limit: int = 20,
    ) -> list[dict]:
        pass


@dataclass(frozen=True)
class GoalCommand:
    kind: str
    title: str
    body: str
    record_type: str
    due_text: Optional[str] = None
    target_text: Optional[str] = None

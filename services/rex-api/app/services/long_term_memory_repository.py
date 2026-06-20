import re
from typing import Optional

from app.services.memory_categories import (
    VALID_MEMORY_CATEGORIES,
    normalize_memory_category,
)
from app.services.memory_errors import MemoryServiceError

VALID_MEMORY_TYPES = {"fact", "preference", "event"}
LONG_TERM_MEMORY_SELECT = (
    "id,memory_type,content,source_conversation_id,source_message_id,"
    "importance,active,superseded_by,confidence,correction_group,metadata,"
    "created_at,updated_at,last_accessed_at"
)


class LongTermMemoryRepository:
    def __init__(self, store: object) -> None:
        self.store = store

    async def save_long_term_memory(
        self,
        memory_type: str,
        content: str,
        source_conversation_id: Optional[str] = None,
        source_message_id: Optional[str] = None,
        importance: int = 3,
        confidence: float = 0.75,
        correction_group: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> dict:
        memory_metadata = dict(metadata or {})
        memory_metadata["memory_category"] = self.infer_memory_category(
            memory_type,
            content,
            memory_metadata,
        )
        rows = await self.store._request(
            "POST",
            self.store.settings.supabase_long_term_memory_table,
            body={
                "memory_type": memory_type,
                "content": content,
                "source_conversation_id": source_conversation_id,
                "source_message_id": source_message_id,
                "importance": importance,
                "confidence": confidence,
                "correction_group": correction_group,
                "metadata": memory_metadata,
            },
            query={"select": LONG_TERM_MEMORY_SELECT},
            prefer="return=representation",
        )
        return self.store._first_row(rows)

    async def save_long_term_memory_from_message(
        self,
        conversation_id: str,
        message: dict,
    ) -> Optional[dict]:
        """Deprecated: ordinary chat messages must not auto-save into memory."""

        _ = conversation_id, message
        return None

    async def list_long_term_memory(
        self,
        limit: int = 50,
        memory_type: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        self.validate_memory_type(memory_type)
        query = {
            "select": LONG_TERM_MEMORY_SELECT,
            "order": "importance.desc,last_accessed_at.desc,created_at.desc",
            "limit": str(limit),
        }
        if memory_type is not None:
            query["memory_type"] = f"eq.{memory_type}"
        if active is not None:
            query["active"] = f"eq.{str(active).lower()}"

        return await self.store._request(
            "GET",
            self.store.settings.supabase_long_term_memory_table,
            query=query,
        )

    async def update_long_term_memory(
        self,
        memory_id: str,
        memory_type: Optional[str] = None,
        content: Optional[str] = None,
        importance: Optional[int] = None,
        active: Optional[bool] = None,
        superseded_by: Optional[str] = None,
        confidence: Optional[float] = None,
        correction_group: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        self.validate_memory_type(memory_type)
        updates: dict = {}
        if memory_type is not None:
            updates["memory_type"] = memory_type
        if content is not None:
            updates["content"] = content
        if importance is not None:
            if importance < 1 or importance > 5:
                raise MemoryServiceError(
                    "Memory importance must be between 1 and 5.",
                    400,
                )
            updates["importance"] = importance
        if active is not None:
            updates["active"] = active
        if superseded_by is not None:
            updates["superseded_by"] = superseded_by
        if confidence is not None:
            if confidence < 0 or confidence > 1:
                raise MemoryServiceError(
                    "Memory confidence must be between 0 and 1.",
                    400,
                )
            updates["confidence"] = confidence
        if correction_group is not None:
            updates["correction_group"] = correction_group
        if metadata is not None:
            memory_metadata = dict(metadata)
            if memory_type is not None or content is not None:
                memory_metadata["memory_category"] = self.infer_memory_category(
                    memory_type or "",
                    content or "",
                    memory_metadata,
                )
            else:
                memory_metadata["memory_category"] = normalize_memory_category(
                    memory_metadata.get("memory_category"),
                    default="Other",
                )
            updates["metadata"] = memory_metadata

        return await self.store._update_record(
            self.store.settings.supabase_long_term_memory_table,
            memory_id,
            updates=updates,
            select=LONG_TERM_MEMORY_SELECT,
            empty_detail="At least one memory field must be provided.",
        )

    async def deactivate_long_term_memory(self, memory_id: str) -> bool:
        memory = await self.update_long_term_memory(memory_id, active=False)
        return memory is not None

    def memory_from_message_text(self, message: str) -> Optional[dict]:
        text = " ".join(message.strip().split())
        if not text:
            return None

        lowered = text.lower()
        if lowered.startswith(("remember that ", "remember: ")):
            content = re.sub(r"^remember(?: that|:)\s+", "", text, flags=re.I)
            return {
                "memory_type": self.classify_memory(content),
                "content": content,
                "importance": 5,
            }

        if re.match(r"^i (prefer|like|love|hate|dislike|want|need)\b", lowered):
            return {
                "memory_type": "preference",
                "content": text,
                "importance": 4,
            }

        if re.match(r"^i (am|work|live|have|own|use)\b", lowered):
            return {
                "memory_type": "fact",
                "content": text,
                "importance": 3,
            }

        event_markers = (
            "my birthday is",
            "my anniversary is",
            "i started",
            "i moved",
            "i graduated",
            "i got married",
        )
        if any(marker in lowered for marker in event_markers):
            return {
                "memory_type": "event",
                "content": text,
                "importance": 4,
            }

        return None

    def classify_memory(self, content: str) -> str:
        lowered = content.lower()
        if any(
            word in lowered
            for word in ("prefer", "like", "love", "hate", "want")
        ):
            return "preference"
        if any(word in lowered for word in ("birthday", "anniversary", "started")):
            return "event"

        return "fact"

    def infer_memory_category(
        self,
        memory_type: str,
        content: str,
        metadata: Optional[dict] = None,
    ) -> str:
        metadata = metadata or {}
        existing_raw = metadata.get("memory_category")
        existing = normalize_memory_category(
            existing_raw,
            default="Other",
        )
        if existing != "Other" or self._explicit_other_category(existing_raw):
            return existing

        fact_kind = str(metadata.get("fact_kind") or "").lower()
        lowered = content.lower()
        if fact_kind in {"name", "work"}:
            return "People"
        if fact_kind in {"birthday"}:
            return "Events"
        if fact_kind in {"location"}:
            return "Places"
        if fact_kind in {"preference"} or memory_type == "preference":
            return "Preferences"
        if fact_kind in {"personal_plan"} or memory_type == "event":
            return "Goals" if fact_kind == "personal_plan" else "Events"
        if any(word in lowered for word in ("birthday", "anniversary")):
            return "Events"
        if any(
            word in lowered
            for word in ("live in", "lives in", "location", "city")
        ):
            return "Places"
        return "Facts"

    def _explicit_other_category(self, value: object) -> bool:
        if not isinstance(value, str):
            return False
        return value.strip().lower().replace("_", " ").replace("-", " ") == "other"

    def validate_memory_type(self, memory_type: Optional[str]) -> None:
        if memory_type is not None and memory_type not in VALID_MEMORY_TYPES:
            raise MemoryServiceError("Invalid memory type.", 400)

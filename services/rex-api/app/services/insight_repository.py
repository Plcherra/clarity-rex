from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Optional

from app.config import Settings, get_settings
from app.services.insight_generator import GeneratedInsight
from app.services.memory_errors import MemoryServiceError
from app.services.supabase_memory_transport import SupabaseMemoryTransport


class InsightRepository(SupabaseMemoryTransport):
    def __init__(
        self,
        *,
        user_id: str,
        access_token: str,
        settings: Optional[Settings] = None,
    ) -> None:
        self.user_id = user_id
        self.access_token = access_token
        self.settings = settings or get_settings()

    async def list_insights(self, *, limit: int = 50) -> list[dict[str, Any]]:
        rows = await self._list_records(
            "user_insights",
            select="*",
            filters={"user_id": self.user_id},
            order="generated_at.desc",
            limit=limit,
        )
        return [row for row in rows if row.get("dismissed_at") is None]

    async def upsert_insight(self, insight: GeneratedInsight) -> str:
        existing = await self._list_records(
            "user_insights",
            select="id,read_at,dismissed_at",
            filters={
                "user_id": self.user_id,
                "fingerprint": insight.fingerprint,
            },
            limit=1,
        )
        now = datetime.now(timezone.utc).isoformat()
        body = {
            "user_id": self.user_id,
            "fingerprint": insight.fingerprint,
            "source": insight.source,
            "insight_type": insight.insight_type,
            "title": insight.title,
            "body": insight.body,
            "period_key": insight.period_key,
            "anchor_key": insight.anchor_key,
            "payload_json": insight.payload_json or {},
            "generated_at": now,
        }
        if existing:
            row = existing[0]
            await self._request(
                "PATCH",
                "user_insights",
                body={
                    "title": body["title"],
                    "body": body["body"],
                    "anchor_key": body["anchor_key"],
                    "payload_json": body["payload_json"],
                    "generated_at": body["generated_at"],
                },
                query={
                    "id": f"eq.{row['id']}",
                    "select": "id",
                },
                prefer="return=minimal",
            )
            return "updated"

        await self._request(
            "POST",
            "user_insights",
            body=body,
            query={"select": "id"},
            prefer="return=minimal",
        )
        return "created"

    async def mark_read(self, insight_id: str) -> Optional[dict[str, Any]]:
        now = datetime.now(timezone.utc).isoformat()
        rows = await self._request(
            "PATCH",
            "user_insights",
            body={"read_at": now},
            query={
                "id": f"eq.{insight_id}",
                "user_id": f"eq.{self.user_id}",
                "select": "*",
            },
            prefer="return=representation",
        )
        return rows[0] if rows else None

    async def fetch_proactive_insights_enabled(self) -> bool:
        rows = await self._list_records(
            "profiles",
            select="proactive_insights_enabled",
            filters={"id": self.user_id},
            limit=1,
        )
        if not rows:
            return False
        return bool(rows[0].get("proactive_insights_enabled"))

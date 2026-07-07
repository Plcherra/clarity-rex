"""Load assistant companion settings from Supabase profiles."""

from __future__ import annotations

from typing import Any, Optional

from app.config import Settings, get_settings
from app.services.assistant_proposal_settings import (
    AssistantProposalSettings,
    resolve_assistant_proposal_settings,
)
from app.services.supabase_memory_transport import SupabaseMemoryTransport


class AssistantSettingsRepository(SupabaseMemoryTransport):
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

    async def fetch_proposal_settings(self) -> AssistantProposalSettings:
        rows = await self._list_records(
            "profiles",
            select="assistant_settings",
            filters={"id": self.user_id},
            limit=1,
        )
        profile_settings: dict[str, Any] = {}
        if rows:
            raw = rows[0].get("assistant_settings")
            if isinstance(raw, dict):
                profile_settings = raw
        return resolve_assistant_proposal_settings(profile_settings)

"""Load assistant companion settings from Supabase profiles."""

from __future__ import annotations

import logging
from typing import Any, Optional

from app.config import Settings, get_settings
from app.services.assistant_proposal_settings import (
    AssistantProposalSettings,
    resolve_assistant_proposal_settings,
)
from app.services.memory_service import MemoryServiceError
from app.services.supabase_memory_transport import SupabaseMemoryTransport

LOGGER = logging.getLogger("clarity.assistant_settings")


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
        try:
            rows = await self._list_records(
                "profiles",
                select="assistant_settings",
                filters={"id": self.user_id},
                limit=1,
            )
        except MemoryServiceError as error:
            LOGGER.warning(
                "assistant_settings_load_failed user_id=%s error=%s",
                self.user_id,
                error,
            )
            return resolve_assistant_proposal_settings({})
        except Exception as error:
            LOGGER.warning(
                "assistant_settings_load_failed user_id=%s error_class=%s",
                self.user_id,
                error.__class__.__name__,
            )
            return resolve_assistant_proposal_settings({})

        profile_settings: dict[str, Any] = {}
        if rows:
            raw = rows[0].get("assistant_settings")
            if isinstance(raw, dict):
                profile_settings = raw
        return resolve_assistant_proposal_settings(profile_settings)

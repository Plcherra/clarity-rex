"""Load assistant companion settings from Supabase profiles."""

from __future__ import annotations

import logging
from typing import Any, Optional

from app.config import Settings, get_settings
from app.services.assistant_proposal_settings import (
    SETTINGS_LOAD_EMPTY_PROFILE,
    SETTINGS_LOAD_FAIL_CLOSED,
    SETTINGS_LOAD_OK,
    AssistantProposalSettings,
    ProposalSettingsResolution,
    fail_closed_resolution,
    resolve_proposal_settings_resolution,
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
        return (await self.fetch_proposal_settings_resolution()).settings

    async def fetch_proposal_settings_resolution(self) -> ProposalSettingsResolution:
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
            return fail_closed_resolution(
                settings_load_status=SETTINGS_LOAD_FAIL_CLOSED,
                settings=self.settings,
            )
        except Exception as error:
            LOGGER.warning(
                "assistant_settings_load_failed user_id=%s error_class=%s",
                self.user_id,
                error.__class__.__name__,
            )
            return fail_closed_resolution(
                settings_load_status=SETTINGS_LOAD_FAIL_CLOSED,
                settings=self.settings,
            )

        profile_settings: dict[str, Any] = {}
        if rows:
            raw = rows[0].get("assistant_settings")
            if isinstance(raw, dict):
                profile_settings = raw

        if not profile_settings:
            return resolve_proposal_settings_resolution(
                {},
                settings=self.settings,
                settings_load_status=SETTINGS_LOAD_EMPTY_PROFILE,
            )

        mode = profile_settings.get("auto_proposals_mode")
        load_status = (
            SETTINGS_LOAD_OK
            if isinstance(mode, str) and mode.strip()
            else SETTINGS_LOAD_EMPTY_PROFILE
        )
        return resolve_proposal_settings_resolution(
            profile_settings,
            settings=self.settings,
            settings_load_status=load_status,
        )

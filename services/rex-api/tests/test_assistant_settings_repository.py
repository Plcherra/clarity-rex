import pytest

from app.config import Settings
from app.services.assistant_proposal_settings import (
    AUTO_PROPOSALS_CARD,
    AUTO_PROPOSALS_OFF,
    AUTO_PROPOSALS_TEXT,
    SETTINGS_LOAD_FAIL_CLOSED,
    SETTINGS_LOAD_OK,
)
from app.services.assistant_settings_repository import AssistantSettingsRepository
from app.services.memory_service import MemoryServiceError


class _FailingRepository(AssistantSettingsRepository):
    async def _list_records(self, *args, **kwargs):
        raise MemoryServiceError("column profiles.assistant_settings does not exist", 400)


class _ProfileRowsRepository(AssistantSettingsRepository):
    def __init__(self, rows, **kwargs):
        super().__init__(**kwargs)
        self.rows = rows
        self.last_filters = None

    async def _list_records(self, table, select, filters=None, **kwargs):
        assert table == "profiles"
        assert select == "assistant_settings"
        self.last_filters = filters
        return self.rows


@pytest.mark.asyncio
async def test_fetch_proposal_settings_fails_closed_when_profile_query_fails():
    repository = _FailingRepository(
        user_id="user-1",
        access_token="token-1",
    )

    settings = await repository.fetch_proposal_settings()

    assert settings.mode == AUTO_PROPOSALS_OFF
    assert not settings.auto_proposals_enabled()


@pytest.mark.asyncio
async def test_fetch_proposal_settings_resolution_fail_closed_status():
    repository = _FailingRepository(
        user_id="user-1",
        access_token="token-1",
    )

    resolution = await repository.fetch_proposal_settings_resolution()

    assert resolution.settings.mode == AUTO_PROPOSALS_OFF
    assert resolution.settings_load_status == SETTINGS_LOAD_FAIL_CLOSED


@pytest.mark.asyncio
async def test_fetch_proposal_settings_loads_text_mode_from_profile_id(monkeypatch):
    monkeypatch.delenv("REX_AUTO_PROPOSALS_MODE", raising=False)
    from app.config import get_settings

    get_settings.cache_clear()
    repository = _ProfileRowsRepository(
        [{"assistant_settings": {"auto_proposals_mode": "text"}}],
        user_id="user-1",
        access_token="token-1",
        settings=Settings(_env_file=None),
    )

    resolution = await repository.fetch_proposal_settings_resolution()

    assert repository.last_filters == {"id": "user-1"}
    assert resolution.settings.mode == AUTO_PROPOSALS_TEXT
    assert resolution.settings_load_status == SETTINGS_LOAD_OK
    assert resolution.settings.enabled_kinds() == ["threads", "goals", "memory"]
    get_settings.cache_clear()


@pytest.mark.asyncio
async def test_fetch_proposal_settings_loads_card_mode_from_profile_id(monkeypatch):
    monkeypatch.delenv("REX_AUTO_PROPOSALS_MODE", raising=False)
    from app.config import get_settings

    get_settings.cache_clear()
    repository = _ProfileRowsRepository(
        [{"assistant_settings": {"auto_proposals_mode": "card"}}],
        user_id="user-1",
        access_token="token-1",
        settings=Settings(_env_file=None),
    )

    settings = await repository.fetch_proposal_settings()

    assert settings.mode == AUTO_PROPOSALS_CARD
    assert settings.uses_confirm_cards() is True
    get_settings.cache_clear()

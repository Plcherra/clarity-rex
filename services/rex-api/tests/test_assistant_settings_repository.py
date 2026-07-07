import pytest

from app.services.assistant_proposal_settings import AUTO_PROPOSALS_TEXT
from app.services.assistant_settings_repository import AssistantSettingsRepository
from app.services.memory_service import MemoryServiceError


class _FailingRepository(AssistantSettingsRepository):
    async def _list_records(self, *args, **kwargs):
        raise MemoryServiceError("column profiles.assistant_settings does not exist", 400)


@pytest.mark.asyncio
async def test_fetch_proposal_settings_falls_back_when_profile_query_fails():
    repository = _FailingRepository(
        user_id="user-1",
        access_token="token-1",
    )

    settings = await repository.fetch_proposal_settings()

    assert settings.mode == AUTO_PROPOSALS_TEXT

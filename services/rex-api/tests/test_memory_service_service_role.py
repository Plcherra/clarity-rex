"""Constructor hygiene for SupabaseMemoryService service-role access."""

import pytest

from app.config import Settings
from app.services.memory_service import SupabaseMemoryService


def test_memory_service_rejects_implicit_service_role_fallback():
    with pytest.raises(ValueError, match="use_service_role=True"):
        SupabaseMemoryService(
            settings=Settings(_env_file=None),
        )


def test_memory_service_rejects_both_token_and_service_role():
    with pytest.raises(ValueError, match="not both"):
        SupabaseMemoryService(
            settings=Settings(_env_file=None),
            access_token="token",
            use_service_role=True,
        )


def test_memory_service_allows_explicit_service_role():
    service = SupabaseMemoryService(
        settings=Settings(
            supabase_url="https://example.supabase.co",
            supabase_service_role_key="service-key",
            _env_file=None,
        ),
        use_service_role=True,
    )
    assert service.use_service_role is True
    assert service._supabase_auth_token() == "service-key"

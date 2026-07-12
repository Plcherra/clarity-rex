"""Tests for Plaid token encryption key separation."""

import pytest

from app.config import Settings
from app.services.plaid_sync_models import PlaidSyncServiceError
from app.services.plaid_token_service import PlaidTokenService


def test_production_rejects_plaid_secret_fallback():
    service = PlaidTokenService(
        Settings(
            app_environment="production",
            plaid_secret="plaid-api-secret",
            plaid_token_encryption_secret=None,
            _env_file=None,
        )
    )
    with pytest.raises(PlaidSyncServiceError, match="PLAID_TOKEN_ENCRYPTION_SECRET"):
        service.encrypted_access_token_ref("access-sandbox-token")


def test_development_allows_plaid_secret_fallback():
    service = PlaidTokenService(
        Settings(
            app_environment="development",
            plaid_secret="plaid-api-secret",
            plaid_token_encryption_secret=None,
            _env_file=None,
        )
    )
    ref = service.encrypted_access_token_ref("access-sandbox-token")
    assert ref.startswith("fernet:v1:")
    assert service.decrypt_access_token_ref(ref) == "access-sandbox-token"


def test_dedicated_encryption_secret_used_when_present():
    service = PlaidTokenService(
        Settings(
            app_environment="production",
            plaid_secret="plaid-api-secret",
            plaid_token_encryption_secret="dedicated-encryption-secret",
            _env_file=None,
        )
    )
    ref = service.encrypted_access_token_ref("access-sandbox-token")
    assert service.decrypt_access_token_ref(ref) == "access-sandbox-token"

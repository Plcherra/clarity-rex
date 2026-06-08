import pytest

from app.config import Settings
from app.services.plaid_sync_service import PlaidSyncService, PlaidSyncServiceError


class UnusedPlaidClient:
    async def exchange_public_token(self, public_token):
        raise AssertionError("Plaid should not be called for invalid input")


def service() -> PlaidSyncService:
    return PlaidSyncService(
        plaid_client=UnusedPlaidClient(),
        settings=Settings(
            _env_file=None,
            supabase_url="https://example.supabase.co",
            supabase_service_role_key="service-role-key",
            plaid_secret="plaid-secret",
        ),
    )


@pytest.mark.asyncio
async def test_plaid_exchange_validates_required_identifiers():
    plaid_service = service()

    with pytest.raises(PlaidSyncServiceError, match="user_id is required"):
        await plaid_service.exchange_public_token(
            user_id=" ",
            public_token="public-sandbox",
        )

    with pytest.raises(PlaidSyncServiceError, match="Plaid public token is required"):
        await plaid_service.exchange_public_token(
            user_id="user-1",
            public_token=" ",
        )

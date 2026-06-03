import pytest

from app.services.plaid_sync_service import (
    PlaidLinkTokenRequest,
    PlaidNotConfiguredError,
    PlaidPublicTokenExchange,
    PlaidSyncError,
    PlaidSyncService,
)


@pytest.mark.asyncio
async def test_plaid_service_fails_closed_before_configuration():
    service = PlaidSyncService()

    with pytest.raises(PlaidNotConfiguredError):
        await service.create_link_token(PlaidLinkTokenRequest(user_id="user-1"))

    with pytest.raises(PlaidNotConfiguredError):
        await service.exchange_public_token(
            PlaidPublicTokenExchange(user_id="user-1", public_token="public-sandbox")
        )

    with pytest.raises(PlaidNotConfiguredError):
        await service.sync_item(user_id="user-1", item_id="item-1")

    with pytest.raises(PlaidNotConfiguredError):
        await service.disconnect_item(user_id="user-1", item_id="item-1")


@pytest.mark.asyncio
async def test_plaid_service_validates_required_identifiers():
    service = PlaidSyncService()

    with pytest.raises(PlaidSyncError, match="user_id is required"):
        await service.create_link_token(PlaidLinkTokenRequest(user_id=" "))

    with pytest.raises(PlaidSyncError, match="Plaid public token is required"):
        await service.exchange_public_token(
            PlaidPublicTokenExchange(user_id="user-1", public_token=" ")
        )

    with pytest.raises(PlaidSyncError, match="item_id is required"):
        await service.sync_item(user_id="user-1", item_id=" ")

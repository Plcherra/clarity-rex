from __future__ import annotations

from typing import Any, Optional

from app.services.plaid_api_client import PlaidApiClient
from app.services.plaid_cursor_service import PlaidCursorService
from app.services.plaid_transaction_sync import PlaidTransactionSync


class PlaidTransactionService:
    def __init__(
        self,
        *,
        plaid_client: PlaidApiClient,
        cursor_service: PlaidCursorService,
        transaction_sync: Optional[PlaidTransactionSync] = None,
    ) -> None:
        self.transaction_sync = transaction_sync or PlaidTransactionSync(
            plaid_client=plaid_client,
            cursor_service=cursor_service,
        )

    async def sync_transactions(
        self,
        *,
        user_id: str,
        item_id: str,
        access_token: str,
        cursor: Optional[str],
        account_map: dict[str, str],
    ) -> dict[str, Any]:
        return await self.transaction_sync.sync_transactions(
            user_id=user_id,
            item_id=item_id,
            access_token=access_token,
            cursor=cursor,
            account_map=account_map,
        )

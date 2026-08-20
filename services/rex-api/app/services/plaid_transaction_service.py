from __future__ import annotations

from typing import Any, Optional

from app.services.plaid_api_client import PlaidApiClient
from app.services.plaid_cursor_service import PlaidCursorService
from app.services.plaid_transaction_dedupe import PlaidTransactionDedupe
from app.services.plaid_transaction_mapper import DEFAULT_APP_TIMEZONE
from app.services.plaid_transaction_sync import PlaidTransactionSync


class PlaidTransactionService:
    def __init__(
        self,
        *,
        plaid_client: PlaidApiClient,
        cursor_service: PlaidCursorService,
        transaction_sync: Optional[PlaidTransactionSync] = None,
        app_timezone: str = DEFAULT_APP_TIMEZONE,
    ) -> None:
        self.transaction_sync = transaction_sync or PlaidTransactionSync(
            plaid_client=plaid_client,
            cursor_service=cursor_service,
            app_timezone=app_timezone,
        )
        self.dedupe = PlaidTransactionDedupe(cursor_service=cursor_service)

    async def sync_transactions(
        self,
        *,
        user_id: str,
        item_id: str,
        access_token: str,
        cursor: Optional[str],
        account_map: dict[str, str],
    ) -> dict[str, Any]:
        result = await self.transaction_sync.sync_transactions(
            user_id=user_id,
            item_id=item_id,
            access_token=access_token,
            cursor=cursor,
            account_map=account_map,
        )
        deleted = await self.dedupe.delete_replaced_item_duplicates(
            user_id=user_id,
            keep_item_id=item_id,
        )
        if deleted:
            result = {**result, "duplicates_deleted": deleted}
        return result

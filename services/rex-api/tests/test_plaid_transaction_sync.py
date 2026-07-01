import pytest

from app.services.plaid_sync_models import PlaidSyncServiceError
from app.services.plaid_transaction_mapper import map_plaid_transaction
from app.services.plaid_transaction_sync import PlaidTransactionSync


class SinglePagePlaidClient:
    def __init__(self):
        self.cursors = []
        self.get_transaction_calls = []

    async def get_transactions(
        self,
        access_token,
        *,
        start_date,
        end_date,
        offset=0,
        count=500,
    ):
        self.get_transaction_calls.append(
            {
                "access_token": access_token,
                "start_date": start_date,
                "end_date": end_date,
                "offset": offset,
                "count": count,
            }
        )
        return {"transactions": [], "total_transactions": 0}

    async def sync_transactions(self, access_token, *, cursor=None, count=100):
        assert access_token == "access-token-secret"
        self.cursors.append(cursor)
        return {
            "added": [
                {
                    "transaction_id": "txn-added-1",
                    "account_id": "plaid-account-1",
                    "amount": 12.5,
                    "date": "2026-06-01",
                    "name": "Coffee",
                    "merchant_name": "Coffee Shop",
                    "pending": True,
                    "pending_transaction_id": "pending-1",
                }
            ],
            "modified": [],
            "removed": [{"transaction_id": "txn-removed-1"}],
            "next_cursor": "cursor-next",
            "has_more": False,
        }


class FailingCursorUpdatePlaidClient(SinglePagePlaidClient):
    pass


class EmptyPlaidClient(SinglePagePlaidClient):
    async def sync_transactions(self, access_token, *, cursor=None, count=100):
        return {
            "added": [],
            "modified": [],
            "removed": [],
            "next_cursor": "cursor-next",
            "has_more": False,
        }


class FakeCursorService:
    def __init__(self, *, fail_cursor_update=False):
        self.calls = []
        self.transaction_ids = set()
        self.fail_cursor_update = fail_cursor_update
        self.uncategorized_transactions = []
        self.categories = [
            {
                "id": "category-coffee",
                "name": "Coffee / Quick Food",
                "normalized_name": "coffee quick food",
            },
            {
                "id": "category-grocery",
                "name": "Grocery / Supermarket",
                "normalized_name": "grocery and supermarket",
            },
        ]

    async def supabase_request(
        self,
        method,
        table,
        *,
        body=None,
        query=None,
        prefer=None,
    ):
        self.calls.append(
            {
                "method": method,
                "table": table,
                "body": body,
                "query": query,
                "prefer": prefer,
            }
        )
        if method == "POST" and table == "transactions":
            assert query == {"on_conflict": "user_id,plaid_transaction_id"}
            self.transaction_ids.add(body["plaid_transaction_id"])
        if method == "GET" and table == "categories":
            return self.categories
        if method == "GET" and table == "transactions":
            return self.uncategorized_transactions
        if method == "POST" and table == "categories":
            category_id = f"category-created-{len(self.categories) + 1}"
            row = {
                "id": category_id,
                "name": body["name"],
                "normalized_name": body["normalized_name"],
            }
            self.categories.append(row)
            return [row]
        return []

    async def update_item_after_sync(self, item_id, next_cursor):
        self.calls.append(
            {
                "method": "PATCH_CURSOR",
                "item_id": item_id,
                "next_cursor": next_cursor,
            }
        )
        if self.fail_cursor_update:
            raise PlaidSyncServiceError("Cannot save Plaid connection right now.")


def test_mapper_preserves_pending_transaction_fields():
    payload = map_plaid_transaction(
        user_id="user-1",
        item_id="item-record-1",
        linked_account_id="account-1",
        transaction={
            "transaction_id": "txn-1",
            "account_id": "plaid-account-1",
            "amount": 10.5,
            "date": "2026-06-01",
            "name": "Coffee",
            "pending": True,
            "pending_transaction_id": "pending-1",
        },
    )

    assert payload["source"] == "plaid"
    assert payload["pending"] is True
    assert payload["plaid_pending_transaction_id"] == "pending-1"
    assert payload["removed_at"] is None


def test_mapper_prefers_authorized_date_over_posting_date():
    payload = map_plaid_transaction(
        user_id="user-1",
        item_id="item-record-1",
        linked_account_id="account-1",
        transaction={
            "transaction_id": "txn-2",
            "account_id": "plaid-account-1",
            "amount": 42.0,
            "date": "2026-07-01",
            "authorized_date": "2026-06-30",
            "name": "Late dinner",
            "pending": False,
        },
    )

    assert payload["date"] == "2026-06-30"


def test_mapper_prefers_authorized_datetime_when_authorized_date_missing():
    payload = map_plaid_transaction(
        user_id="user-1",
        item_id="item-record-1",
        linked_account_id="account-1",
        transaction={
            "transaction_id": "txn-3",
            "account_id": "plaid-account-1",
            "amount": 12.0,
            "date": "2026-07-01",
            "authorized_datetime": "2026-06-30T21:15:00-04:00",
            "name": "Late dinner",
            "pending": False,
        },
    )

    assert payload["date"] == "2026-06-30"


def test_mapper_authorized_datetime_utc_uses_app_timezone_calendar_date():
    """9:15pm ET on June 30 must not become July 1 when Plaid sends UTC Z."""
    payload = map_plaid_transaction(
        user_id="user-1",
        item_id="item-record-1",
        linked_account_id="account-1",
        transaction={
            "transaction_id": "txn-4",
            "account_id": "plaid-account-1",
            "amount": 12.0,
            "date": "2026-07-01",
            "authorized_datetime": "2026-07-01T01:15:00Z",
            "name": "Late dinner",
            "pending": False,
        },
    )

    assert payload["date"] == "2026-06-30"


@pytest.mark.asyncio
async def test_transaction_sync_upserts_removes_and_updates_cursor_last():
    plaid_client = SinglePagePlaidClient()
    cursor_service = FakeCursorService()
    sync = PlaidTransactionSync(
        plaid_client=plaid_client,
        cursor_service=cursor_service,
    )

    result = await sync.sync_transactions(
        user_id="user-1",
        item_id="item-record-1",
        access_token="access-token-secret",
        cursor="cursor-old",
        account_map={"plaid-account-1": "linked-account-1"},
    )

    assert result == {
        "added": 1,
        "modified": 0,
        "removed": 1,
        "next_cursor": "cursor-next",
        "dates_repaired": 0,
    }
    assert plaid_client.cursors == ["cursor-old"]
    assert {
        "method": "PATCH_CURSOR",
        "item_id": "item-record-1",
        "next_cursor": "cursor-next",
    } in cursor_service.calls

    upsert_call = next(
        call
        for call in cursor_service.calls
        if call.get("method") == "POST" and call.get("table") == "transactions"
    )
    assert upsert_call["method"] == "POST"
    assert upsert_call["body"]["pending"] is True
    assert upsert_call["body"]["category_id"] == "category-coffee"
    assert upsert_call["prefer"] == "resolution=merge-duplicates,return=minimal"

    remove_call = next(
        call
        for call in cursor_service.calls
        if call.get("method") == "PATCH" and call.get("table") == "transactions"
    )
    assert remove_call["method"] == "PATCH"
    assert remove_call["body"]["removed_at"] is not None
    assert remove_call["query"]["source"] == "eq.plaid"


@pytest.mark.asyncio
async def test_transaction_sync_is_idempotent_by_plaid_transaction_id():
    plaid_client = SinglePagePlaidClient()
    cursor_service = FakeCursorService()
    sync = PlaidTransactionSync(
        plaid_client=plaid_client,
        cursor_service=cursor_service,
    )

    for _ in range(2):
        await sync.sync_transactions(
            user_id="user-1",
            item_id="item-record-1",
            access_token="access-token-secret",
            cursor="cursor-old",
            account_map={"plaid-account-1": "linked-account-1"},
        )

    assert cursor_service.transaction_ids == {"txn-added-1"}
    upsert_calls = [
        call
        for call in cursor_service.calls
        if call.get("method") == "POST" and call.get("table") == "transactions"
    ]
    assert len(upsert_calls) == 2
    assert all(
        call["query"] == {"on_conflict": "user_id,plaid_transaction_id"}
        for call in upsert_calls
    )


@pytest.mark.asyncio
async def test_transaction_sync_does_not_advance_cursor_before_storage_success():
    cursor_service = FakeCursorService(fail_cursor_update=True)
    sync = PlaidTransactionSync(
        plaid_client=FailingCursorUpdatePlaidClient(),
        cursor_service=cursor_service,
    )

    with pytest.raises(PlaidSyncServiceError, match="Cannot save"):
        await sync.sync_transactions(
            user_id="user-1",
            item_id="item-record-1",
            access_token="access-token-secret",
            cursor="cursor-old",
            account_map={"plaid-account-1": "linked-account-1"},
        )

    assert cursor_service.calls[-1]["method"] == "PATCH_CURSOR"
    assert cursor_service.calls[-2]["method"] == "PATCH"


@pytest.mark.asyncio
async def test_transaction_sync_creates_missing_clarity_category_from_plaid_pfc():
    class GroceryPlaidClient(SinglePagePlaidClient):
        async def sync_transactions(self, access_token, *, cursor=None, count=100):
            return {
                "added": [
                    {
                        "transaction_id": "txn-grocery-1",
                        "account_id": "plaid-account-1",
                        "amount": 42.5,
                        "date": "2026-06-01",
                        "name": "Market Purchase",
                        "pending": False,
                        "personal_finance_category": {
                            "primary": "FOOD_AND_DRINK",
                            "detailed": "FOOD_AND_DRINK_GROCERIES",
                        },
                    }
                ],
                "modified": [],
                "removed": [],
                "next_cursor": "cursor-next",
                "has_more": False,
            }

    cursor_service = FakeCursorService()
    cursor_service.categories = []
    sync = PlaidTransactionSync(
        plaid_client=GroceryPlaidClient(),
        cursor_service=cursor_service,
    )

    await sync.sync_transactions(
        user_id="user-1",
        item_id="item-record-1",
        access_token="access-token-secret",
        cursor=None,
        account_map={"plaid-account-1": "linked-account-1"},
    )

    category_call = next(
        call
        for call in cursor_service.calls
        if call.get("method") == "POST" and call.get("table") == "categories"
    )
    assert category_call["body"]["name"] == "Grocery / Supermarket"
    assert category_call["body"]["type"] == "expense"

    upsert_call = next(
        call
        for call in cursor_service.calls
        if call.get("method") == "POST" and call.get("table") == "transactions"
    )
    assert upsert_call["body"]["category_id"] == "category-created-1"


@pytest.mark.asyncio
async def test_transaction_sync_reuses_existing_normalized_category_from_plaid_pfc():
    class GroceryPlaidClient(SinglePagePlaidClient):
        async def sync_transactions(self, access_token, *, cursor=None, count=100):
            return {
                "added": [
                    {
                        "transaction_id": "txn-grocery-existing",
                        "account_id": "plaid-account-1",
                        "amount": 32.75,
                        "date": "2026-06-01",
                        "name": "Grocery Purchase",
                        "pending": False,
                        "personal_finance_category": {
                            "primary": "FOOD_AND_DRINK",
                            "detailed": "FOOD_AND_DRINK_GROCERIES",
                        },
                    }
                ],
                "modified": [],
                "removed": [],
                "next_cursor": "cursor-next",
                "has_more": False,
            }

    cursor_service = FakeCursorService()
    sync = PlaidTransactionSync(
        plaid_client=GroceryPlaidClient(),
        cursor_service=cursor_service,
    )

    await sync.sync_transactions(
        user_id="user-1",
        item_id="item-record-1",
        access_token="access-token-secret",
        cursor=None,
        account_map={"plaid-account-1": "linked-account-1"},
    )

    category_create_calls = [
        call
        for call in cursor_service.calls
        if call.get("method") == "POST" and call.get("table") == "categories"
    ]
    assert category_create_calls == []

    upsert_call = next(
        call
        for call in cursor_service.calls
        if call.get("method") == "POST" and call.get("table") == "transactions"
    )
    assert upsert_call["body"]["category_id"] == "category-grocery"


@pytest.mark.asyncio
async def test_transaction_sync_assigns_fallback_category_when_plaid_has_no_category():
    class UnknownPlaidClient(SinglePagePlaidClient):
        async def sync_transactions(self, access_token, *, cursor=None, count=100):
            return {
                "added": [
                    {
                        "transaction_id": "txn-unknown-1",
                        "account_id": "plaid-account-1",
                        "amount": 19.99,
                        "date": "2026-06-01",
                        "name": "UNKNOWN MERCHANT",
                        "pending": False,
                    }
                ],
                "modified": [],
                "removed": [],
                "next_cursor": "cursor-next",
                "has_more": False,
            }

    cursor_service = FakeCursorService()
    cursor_service.categories = []
    sync = PlaidTransactionSync(
        plaid_client=UnknownPlaidClient(),
        cursor_service=cursor_service,
    )

    await sync.sync_transactions(
        user_id="user-1",
        item_id="item-record-1",
        access_token="access-token-secret",
        cursor=None,
        account_map={"plaid-account-1": "linked-account-1"},
    )

    category_call = next(
        call
        for call in cursor_service.calls
        if call.get("method") == "POST" and call.get("table") == "categories"
    )
    assert category_call["body"]["name"] == "Miscellaneous"

    upsert_call = next(
        call
        for call in cursor_service.calls
        if call.get("method") == "POST" and call.get("table") == "transactions"
    )
    assert upsert_call["body"]["category_id"] == "category-created-1"


@pytest.mark.asyncio
async def test_transaction_sync_backfills_existing_uncategorized_plaid_rows():
    cursor_service = FakeCursorService()
    cursor_service.categories = []
    cursor_service.uncategorized_transactions = [
        {
            "id": "transaction-existing",
            "description": "CURSOR AI-POWERED IDE",
            "merchant": "CURSOR AI-POWERED IDE",
            "amount": 20.0,
            "type": "expense",
        }
    ]
    sync = PlaidTransactionSync(
        plaid_client=EmptyPlaidClient(),
        cursor_service=cursor_service,
    )

    await sync.sync_transactions(
        user_id="user-1",
        item_id="item-record-1",
        access_token="access-token-secret",
        cursor=None,
        account_map={"plaid-account-1": "linked-account-1"},
    )

    category_call = next(
        call
        for call in cursor_service.calls
        if call.get("method") == "POST" and call.get("table") == "categories"
    )
    assert category_call["body"]["name"] == "Subscriptions"

    backfill_call = next(
        call
        for call in cursor_service.calls
        if call.get("method") == "PATCH"
        and call.get("table") == "transactions"
        and call.get("query", {}).get("id") == "eq.transaction-existing"
    )
    assert backfill_call["body"]["category_id"] == "category-created-1"
    assert backfill_call["query"]["category_id"] == "is.null"


@pytest.mark.asyncio
async def test_transaction_sync_repairs_recent_dates_via_transactions_get():
    class RepairPlaidClient(SinglePagePlaidClient):
        async def sync_transactions(self, access_token, *, cursor=None, count=100):
            return {
                "added": [],
                "modified": [],
                "removed": [],
                "next_cursor": "cursor-next",
                "has_more": False,
            }

        async def get_transactions(
            self,
            access_token,
            *,
            start_date,
            end_date,
            offset=0,
            count=500,
        ):
            await super().get_transactions(
                access_token,
                start_date=start_date,
                end_date=end_date,
                offset=offset,
                count=count,
            )
            return {
                "transactions": [
                    {
                        "transaction_id": "txn-late-night",
                        "account_id": "plaid-account-1",
                        "amount": 18.5,
                        "date": "2026-07-01",
                        "authorized_date": "2026-06-30",
                        "name": "Late purchase",
                        "pending": False,
                    }
                ],
                "total_transactions": 1,
            }

    cursor_service = FakeCursorService()
    plaid_client = RepairPlaidClient()
    sync = PlaidTransactionSync(
        plaid_client=plaid_client,
        cursor_service=cursor_service,
    )

    result = await sync.sync_transactions(
        user_id="user-1",
        item_id="item-record-1",
        access_token="access-token-secret",
        cursor=None,
        account_map={"plaid-account-1": "linked-account-1"},
    )

    assert result["dates_repaired"] == 1
    assert len(plaid_client.get_transaction_calls) == 1
    repair_upsert = next(
        call
        for call in cursor_service.calls
        if call.get("method") == "POST"
        and call.get("table") == "transactions"
        and call.get("body", {}).get("plaid_transaction_id") == "txn-late-night"
    )
    assert repair_upsert["body"]["date"] == "2026-06-30"

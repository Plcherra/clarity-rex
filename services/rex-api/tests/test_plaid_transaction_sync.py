import pytest

from app.services.plaid_sync_models import PlaidSyncServiceError
from app.services.plaid_transaction_mapper import map_plaid_transaction
from app.services.plaid_transaction_sync import PlaidTransactionSync


class SinglePagePlaidClient:
    def __init__(self):
        self.cursors = []

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


class FakeCursorService:
    def __init__(self, *, fail_cursor_update=False):
        self.calls = []
        self.transaction_ids = set()
        self.fail_cursor_update = fail_cursor_update
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
    }
    assert plaid_client.cursors == ["cursor-old"]
    assert cursor_service.calls[-1] == {
        "method": "PATCH_CURSOR",
        "item_id": "item-record-1",
        "next_cursor": "cursor-next",
    }

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

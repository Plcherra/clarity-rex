from __future__ import annotations

import pytest

from app.services.plaid_transaction_dedupe import PlaidTransactionDedupe
from tests.test_plaid_account_relink import FakeCursorService


@pytest.mark.asyncio
async def test_deletes_replaced_item_copy_on_same_account():
    cursor = FakeCursorService()
    cursor.items = [
        {
            "id": "old-item",
            "user_id": "user-1",
            "institution_id": "ins_128026",
            "institution_name": "Capital One",
            "status": "disconnected",
        },
        {
            "id": "new-item",
            "user_id": "user-1",
            "institution_id": "ins_128026",
            "institution_name": "Capital One",
            "status": "active",
        },
    ]
    cursor.transactions = [
        {
            "id": "old-starmarket",
            "user_id": "user-1",
            "account_id": "quicksilver",
            "date": "2026-08-18",
            "amount": "32.39",
            "merchant": "Starmarke",
            "description": "DD *DOORDASH STARMARKE",
            "type": "expense",
            "pending": False,
            "removed_at": None,
            "plaid_item_record_id": "old-item",
        },
        {
            "id": "new-starmarket",
            "user_id": "user-1",
            "account_id": "quicksilver",
            "date": "2026-08-18",
            "amount": "32.39",
            "merchant": "Starmarke",
            "description": "DD *DOORDASH STARMARKE",
            "type": "expense",
            "pending": False,
            "removed_at": None,
            "plaid_item_record_id": "new-item",
        },
        {
            "id": "old-only",
            "user_id": "user-1",
            "account_id": "quicksilver",
            "date": "2026-07-01",
            "amount": "9.99",
            "merchant": "Unique",
            "type": "expense",
            "pending": False,
            "removed_at": None,
            "plaid_item_record_id": "old-item",
        },
    ]
    deleted = await PlaidTransactionDedupe(
        cursor_service=cursor,
    ).delete_replaced_item_duplicates(
        user_id="user-1",
        keep_item_id="new-item",
    )

    assert deleted == 1
    assert {row["id"] for row in cursor.transactions} == {
        "new-starmarket",
        "old-only",
    }


@pytest.mark.asyncio
async def test_keeps_two_same_day_charges_from_the_live_item():
    cursor = FakeCursorService()
    cursor.items = [
        {
            "id": "live-item",
            "user_id": "user-1",
            "institution_id": "ins_3",
            "institution_name": "Bank of America",
            "status": "active",
        },
    ]
    cursor.transactions = [
        {
            "id": "first-coffee",
            "user_id": "user-1",
            "account_id": "checking",
            "date": "2026-08-18",
            "amount": "4.14",
            "merchant": "Bom Dough",
            "type": "expense",
            "pending": False,
            "removed_at": None,
            "plaid_item_record_id": "live-item",
        },
        {
            "id": "second-coffee",
            "user_id": "user-1",
            "account_id": "checking",
            "date": "2026-08-18",
            "amount": "4.14",
            "merchant": "Bom Dough",
            "type": "expense",
            "pending": False,
            "removed_at": None,
            "plaid_item_record_id": "live-item",
        },
    ]

    deleted = await PlaidTransactionDedupe(
        cursor_service=cursor,
    ).delete_replaced_item_duplicates(
        user_id="user-1",
        keep_item_id="live-item",
    )

    assert deleted == 0
    assert len(cursor.transactions) == 2


@pytest.mark.asyncio
async def test_does_not_delete_other_institution_disconnected_rows():
    cursor = FakeCursorService()
    cursor.items = [
        {
            "id": "cap-old",
            "user_id": "user-1",
            "institution_id": "ins_128026",
            "institution_name": "Capital One",
            "status": "disconnected",
        },
        {
            "id": "boa-live",
            "user_id": "user-1",
            "institution_id": "ins_3",
            "institution_name": "Bank of America",
            "status": "active",
        },
    ]
    cursor.transactions = [
        {
            "id": "cap-row",
            "user_id": "user-1",
            "account_id": "quicksilver",
            "date": "2026-08-18",
            "amount": "32.39",
            "merchant": "Starmarke",
            "type": "expense",
            "pending": False,
            "removed_at": None,
            "plaid_item_record_id": "cap-old",
        },
        {
            "id": "boa-row",
            "user_id": "user-1",
            "account_id": "quicksilver",
            "date": "2026-08-18",
            "amount": "32.39",
            "merchant": "Starmarke",
            "type": "expense",
            "pending": False,
            "removed_at": None,
            "plaid_item_record_id": "boa-live",
        },
    ]

    deleted = await PlaidTransactionDedupe(
        cursor_service=cursor,
    ).delete_replaced_item_duplicates(
        user_id="user-1",
        keep_item_id="boa-live",
    )

    assert deleted == 0
    assert len(cursor.transactions) == 2

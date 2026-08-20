from __future__ import annotations

from typing import Any

import pytest

from app.services.plaid_account_relink import PlaidAccountRelinkService


class FakeCursorService:
    def __init__(self) -> None:
        self.plaid_accounts: list[dict[str, Any]] = []
        self.accounts: list[dict[str, Any]] = []
        self.transactions: list[dict[str, Any]] = []
        self.items: list[dict[str, Any]] = []
        self.disconnected: list[str] = []
        self.calls: list[tuple[str, str, dict[str, Any] | None]] = []

    async def mark_item_disconnected(self, *, user_id: str, item_id: str) -> None:
        self.disconnected.append(item_id)
        for item in self.items:
            if item.get("id") == item_id:
                item["status"] = "disconnected"

    async def supabase_request(
        self,
        method: str,
        table: str,
        *,
        body: dict[str, Any] | None = None,
        query: dict[str, str] | None = None,
        prefer: str | None = None,
    ) -> list[dict[str, Any]]:
        self.calls.append((method, table, body))
        filters = query or {}
        if method == "GET" and table == "plaid_accounts":
            return [
                row
                for row in self.plaid_accounts
                if _matches(row, filters, user_key="user_id")
            ]
        if method == "GET" and table == "accounts":
            return [
                row
                for row in self.accounts
                if _matches(row, filters, user_key="user_id")
            ]
        if method == "GET" and table == "transactions":
            return [
                row
                for row in self.transactions
                if _matches(row, filters, user_key="user_id")
            ]
        if method == "GET" and table == "plaid_items":
            return [
                row
                for row in self.items
                if _matches(row, filters, user_key="user_id")
            ]
        if method == "PATCH" and table == "accounts":
            for row in self.accounts:
                if _matches(row, filters, user_key="user_id"):
                    if body:
                        row.update(body)
                    if "select" in filters:
                        return [row]
            return []
        if method == "PATCH" and table == "transactions":
            for row in self.transactions:
                if _matches(row, filters, user_key="user_id"):
                    if body:
                        row.update(body)
            return []
        if method == "PATCH" and table == "plaid_accounts":
            for row in self.plaid_accounts:
                if _matches(row, filters, user_key="user_id"):
                    if body:
                        row.update(body)
            return []
        if method == "DELETE" and table == "transactions":
            self.transactions = [
                row
                for row in self.transactions
                if not _matches(row, filters, user_key="user_id")
            ]
            return []
        if method == "DELETE" and table == "accounts":
            self.accounts = [
                row
                for row in self.accounts
                if not _matches(row, filters, user_key="user_id")
            ]
            self.transactions = [
                row
                for row in self.transactions
                if row.get("account_id")
                != _eq_value(filters.get("id"))
            ]
            return []
        if method == "POST" and table == "accounts":
            created = {"id": "created-account", **(body or {})}
            self.accounts.append(created)
            return [created]
        return []


def _eq_value(raw: str | None) -> str | None:
    if not raw:
        return None
    if raw.startswith("eq."):
        return raw[3:]
    if raw.startswith("neq."):
        return raw[4:]
    return raw


def _matches(row: dict[str, Any], filters: dict[str, str], *, user_key: str) -> bool:
    for key, raw in filters.items():
        if key in {"select", "on_conflict", "limit", "offset"}:
            continue
        if raw.startswith("in.(") and raw.endswith(")"):
            wanted = {part.strip() for part in raw[4:-1].split(",") if part.strip()}
            if str(row.get(key) or "") not in wanted:
                return False
            continue
        if raw == "is.null":
            if row.get(key) is not None:
                return False
            continue
        if raw.startswith("neq."):
            if str(row.get(key) or "") == raw[4:]:
                return False
            continue
        if raw.startswith("eq."):
            expected = raw[3:]
            if key == user_key or key in row:
                if str(row.get(key) or "") != expected:
                    return False
            continue
    return True


@pytest.mark.asyncio
async def test_resolve_prefers_oldest_identity_match_over_new_plaid_id():
    cursor = FakeCursorService()
    cursor.plaid_accounts = [
        {
            "plaid_account_id": "old-plaid",
            "linked_account_id": "old-account",
            "institution_name": "Capital One",
            "mask": "1410",
            "account_type": "credit",
            "account_subtype": "credit card",
            "created_at": "2026-06-11T00:00:00Z",
            "user_id": "user-1",
        },
        {
            "plaid_account_id": "new-plaid",
            "linked_account_id": "new-account",
            "institution_name": "Capital One",
            "mask": "1410",
            "account_type": "credit",
            "account_subtype": "credit card",
            "created_at": "2026-08-20T00:00:00Z",
            "user_id": "user-1",
        },
    ]
    cursor.accounts = [
        {"id": "old-account", "created_at": "2026-06-11T00:00:00Z", "user_id": "user-1"},
        {"id": "new-account", "created_at": "2026-08-20T00:00:00Z", "user_id": "user-1"},
    ]
    service = PlaidAccountRelinkService(cursor_service=cursor)

    resolved = await service.resolve_existing_account_id(
        user_id="user-1",
        plaid_account_id="new-plaid",
        institution_name="Capital One",
        mask="1410",
        account_type="credit",
        account_subtype="credit card",
    )

    assert resolved == "old-account"


@pytest.mark.asyncio
async def test_collapse_merges_duplicate_account_and_keeps_unique_transactions():
    cursor = FakeCursorService()
    cursor.plaid_accounts = [
        {
            "plaid_account_id": "old-plaid",
            "linked_account_id": "old-account",
            "institution_name": "Capital One",
            "mask": "3279",
            "account_type": "depository",
            "account_subtype": "checking",
            "created_at": "2026-06-11T00:00:00Z",
            "user_id": "user-1",
        },
        {
            "plaid_account_id": "new-plaid",
            "linked_account_id": "new-account",
            "institution_name": "Capital One",
            "mask": "3279",
            "account_type": "depository",
            "account_subtype": "checking",
            "created_at": "2026-08-20T00:00:00Z",
            "user_id": "user-1",
        },
    ]
    cursor.accounts = [
        {"id": "old-account", "created_at": "2026-06-11T00:00:00Z", "user_id": "user-1"},
        {"id": "new-account", "created_at": "2026-08-20T00:00:00Z", "user_id": "user-1"},
    ]
    cursor.transactions = [
        {
            "id": "shared-old",
            "account_id": "old-account",
            "date": "2026-08-01",
            "amount": "10.00",
            "merchant": "Coffee",
            "type": "expense",
            "pending": False,
            "removed_at": None,
            "user_id": "user-1",
        },
        {
            "id": "shared-new",
            "account_id": "new-account",
            "date": "2026-08-01",
            "amount": "10.00",
            "merchant": "Coffee",
            "type": "expense",
            "pending": False,
            "removed_at": None,
            "user_id": "user-1",
        },
        {
            "id": "unique-new",
            "account_id": "new-account",
            "date": "2026-08-02",
            "amount": "4.00",
            "merchant": "Transit",
            "type": "expense",
            "pending": False,
            "removed_at": None,
            "user_id": "user-1",
        },
    ]
    service = PlaidAccountRelinkService(cursor_service=cursor)

    await service.collapse_duplicate_accounts(
        user_id="user-1",
        institution_name="Capital One",
    )

    assert [row["id"] for row in cursor.accounts] == ["old-account"]
    assert {row["id"] for row in cursor.transactions} == {"shared-old", "unique-new"}
    assert all(row["account_id"] == "old-account" for row in cursor.transactions)
    assert all(
        row["linked_account_id"] == "old-account" for row in cursor.plaid_accounts
    )


@pytest.mark.asyncio
async def test_disconnect_replaced_items_keeps_current_institution_item():
    cursor = FakeCursorService()
    cursor.items = [
        {
            "id": "old-item",
            "user_id": "user-1",
            "institution_id": "ins_128026",
            "institution_name": "Capital One",
            "status": "active",
        },
        {
            "id": "new-item",
            "user_id": "user-1",
            "institution_id": "ins_128026",
            "institution_name": "Capital One",
            "status": "active",
        },
        {
            "id": "boa-item",
            "user_id": "user-1",
            "institution_id": "ins_3",
            "institution_name": "Bank of America",
            "status": "active",
        },
    ]
    service = PlaidAccountRelinkService(cursor_service=cursor)

    await service.disconnect_replaced_items(
        user_id="user-1",
        keep_item_id="new-item",
        institution_id="ins_128026",
        institution_name="Capital One",
    )

    assert cursor.disconnected == ["old-item"]

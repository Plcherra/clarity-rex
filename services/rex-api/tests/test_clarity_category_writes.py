"""Confirmed category writes: reuse-or-create, then move rows in one action."""

from __future__ import annotations

import pytest

from app.services.clarity_control_service import (
    ClarityControlService,
    ClarityControlServiceError,
)


class FakeSupabase:
    """Records Clarity control requests and answers category lookups."""

    def __init__(self, categories: list[dict] | None = None) -> None:
        self.categories = categories or []
        self.calls: list[dict] = []

    async def request(self, method, table, **kwargs):
        self.calls.append({"method": method, "table": table, **kwargs})
        if method == "GET" and table == "categories":
            return self._lookup(kwargs.get("query") or {})
        if method == "POST" and table == "categories":
            created = {"id": "cat-new", **(kwargs.get("body") or {})}
            self.categories.append(created)
            return [created]
        if method == "GET" and table == "transactions":
            return [
                {"id": "tx-1", "category_id": "cat-misc"},
                {"id": "tx-2", "category_id": "cat-misc"},
            ]
        if method == "PATCH" and table == "transactions":
            return [{"id": "tx-1"}, {"id": "tx-2"}]
        return [{"id": "row-1"}]

    def _lookup(self, query: dict) -> list[dict]:
        for key in ("normalized_name", "name"):
            wanted = str(query.get(key) or "").removeprefix("eq.")
            if not wanted:
                continue
            matches = [row for row in self.categories if row.get(key) == wanted]
            if matches:
                return matches[:1]
        # Plural-aware fallback scans the catalog the same way production does.
        if "select" in query and not any(
            str(query.get(key) or "").startswith("eq.")
            for key in ("normalized_name", "name")
        ):
            return list(self.categories)
        return []

    def call(self, method: str, table: str) -> dict | None:
        for entry in self.calls:
            if entry["method"] == method and entry["table"] == table:
                return entry
        return None


def service_with(fake: FakeSupabase) -> ClarityControlService:
    service = ClarityControlService(user_id="user-1", access_token="token")
    service._request = fake.request
    return service


@pytest.mark.asyncio
async def test_create_category_reuses_the_category_the_user_already_has() -> None:
    fake = FakeSupabase(
        [{"id": "cat-fast-food", "name": "Fast Food", "normalized_name": "fast food"}]
    )

    result = await service_with(fake).execute(
        "create_category",
        {"name": "  fast food  ", "type": "expense"},
        confirmed=True,
    )

    assert result == [
        {"id": "cat-fast-food", "name": "Fast Food", "normalized_name": "fast food"}
    ]
    assert fake.call("POST", "categories") is None


@pytest.mark.asyncio
async def test_singular_spoken_name_reuses_the_plural_category() -> None:
    """User said 'work reimbursement'; Knows already has Work Reimbursements."""
    fake = FakeSupabase(
        [
            {
                "id": "cat-reimb",
                "name": "Work Reimbursements",
                "normalized_name": "work reimbursements",
            }
        ]
    )

    result = await service_with(fake).execute(
        "create_category",
        {"name": "work reimbursement", "type": "expense"},
        confirmed=True,
    )

    assert result[0]["id"] == "cat-reimb"
    assert fake.call("POST", "categories") is None


@pytest.mark.asyncio
async def test_create_category_stores_the_name_the_app_would_store() -> None:
    fake = FakeSupabase()

    await service_with(fake).execute(
        "create_category",
        {"name": "fast food"},
        confirmed=True,
    )

    assert fake.call("POST", "categories")["body"] == {
        "name": "Fast Food",
        "normalized_name": "fast food",
        "type": "expense",
    }


@pytest.mark.asyncio
async def test_moving_rows_into_a_new_category_creates_it_then_moves_them() -> None:
    fake = FakeSupabase(
        [{"id": "cat-misc", "name": "Miscellaneous", "normalized_name": "miscellaneous"}]
    )

    result = await service_with(fake).execute(
        "bulk_update_transaction_category",
        {
            "merchant": "Wingstop",
            "new_category": {"name": "Fast Food", "type": "expense"},
        },
        confirmed=True,
    )

    assert result[0]["id"] == "tx-1"
    assert result[0]["_audit_previous_category_name"] == "Miscellaneous"
    assert result[0]["_audit_category_name"] == "Fast Food"
    move = fake.call("PATCH", "transactions")
    assert move["body"] == {"category_id": "cat-new"}
    assert move["query"] == {
        "or": '(description.ilike."*wingstop*",merchant.ilike."*wingstop*")',
        "select": "*",
    }


@pytest.mark.asyncio
async def test_merchant_moves_cover_rows_the_assistant_never_saw() -> None:
    """Ids would only cover the sampled context pack; the merchant filter does not."""
    fake = FakeSupabase()

    await service_with(fake).execute(
        "bulk_update_transaction_category",
        {"merchant": "Bom Dough (card *1234)", "category_id": "cat-coffee"},
        confirmed=True,
    )

    # Each word stands on its own, so the card digits Grok echoed cannot stop
    # the rows the user meant from matching.
    move = fake.call("PATCH", "transactions")
    assert move["query"]["and"] == (
        '(or(description.ilike."*bom*",merchant.ilike."*bom*"),'
        'or(description.ilike."*dough*",merchant.ilike."*dough*"))'
    )


@pytest.mark.asyncio
async def test_named_ids_still_move_exactly_those_rows() -> None:
    fake = FakeSupabase()

    await service_with(fake).execute(
        "bulk_update_transaction_category",
        {"ids": ["tx-1", " tx-2 "], "category_id": "cat-coffee"},
        confirmed=True,
    )

    assert fake.call("PATCH", "transactions")["query"] == {
        "id": "in.(tx-1,tx-2)",
        "select": "*",
    }


@pytest.mark.asyncio
async def test_a_move_without_a_target_category_is_refused() -> None:
    fake = FakeSupabase()

    with pytest.raises(ClarityControlServiceError):
        await service_with(fake).execute(
            "bulk_update_transaction_category",
            {"ids": ["tx-1"]},
            confirmed=True,
        )

    assert fake.call("PATCH", "transactions") is None


@pytest.mark.asyncio
async def test_a_move_without_rows_to_match_is_refused() -> None:
    fake = FakeSupabase()

    with pytest.raises(ClarityControlServiceError):
        await service_with(fake).execute(
            "bulk_update_transaction_category",
            {"category_id": "cat-coffee"},
            confirmed=True,
        )

    assert fake.call("PATCH", "transactions") is None


@pytest.mark.asyncio
async def test_renaming_a_category_keeps_the_key_the_app_matches_on() -> None:
    fake = FakeSupabase()

    await service_with(fake).execute(
        "update_category",
        {"id": "cat-coffee", "name": "coffee & tea"},
        confirmed=True,
    )

    assert fake.call("PATCH", "categories")["body"] == {
        "name": "Coffee And Tea",
        "normalized_name": "coffee tea",
    }

"""Unit tests for fail-closed discipline list loading."""

from __future__ import annotations

import logging

import pytest

from app.services.memory_discipline_list_loader import (
    DisciplineContextLoadError,
    safe_discipline_list,
)
from app.services.product_events import product_event_counts, reset_product_event_counts


class _Repo:
    def __init__(self):
        self.calls = []

    async def list_long_term_memory(self, *, active=True, limit=100):
        self.calls.append(("list_long_term_memory", active, limit))
        return [{"id": "memory-1", "content": "Mom birthday", "active": True}]

    async def list_narrow(self, limit=50):
        self.calls.append(("list_narrow", limit))
        return [{"id": "narrow-1"}]

    async def list_broken(self, **_kwargs):
        raise RuntimeError("db unavailable")


@pytest.mark.asyncio
async def test_safe_discipline_list_returns_rows_on_success():
    repo = _Repo()

    rows = await safe_discipline_list(
        repo,
        "list_long_term_memory",
        active=True,
        limit=25,
    )

    assert rows == [{"id": "memory-1", "content": "Mom birthday", "active": True}]
    assert repo.calls == [("list_long_term_memory", True, 25)]


@pytest.mark.asyncio
async def test_safe_discipline_list_missing_method_returns_empty():
    rows = await safe_discipline_list(object(), "list_entities", limit=10)
    assert rows == []


@pytest.mark.asyncio
async def test_safe_discipline_list_typeerror_falls_back_to_limit_only():
    repo = _Repo()

    rows = await safe_discipline_list(
        repo,
        "list_narrow",
        scan_limit=40,
        active=True,
        limit=40,
    )

    assert rows == [{"id": "narrow-1"}]
    assert repo.calls == [("list_narrow", 40)]


@pytest.mark.asyncio
async def test_safe_discipline_list_fails_closed_and_logs(caplog):
    repo = _Repo()
    reset_product_event_counts()

    with caplog.at_level(logging.WARNING, logger="rex.memory.failure"):
        with pytest.raises(DisciplineContextLoadError) as exc_info:
            await safe_discipline_list(repo, "list_broken", limit=10)

    assert exc_info.value.operation == "list_broken"
    assert isinstance(exc_info.value.cause, RuntimeError)
    assert "discipline_context_unavailable:list_broken" in str(exc_info.value)
    assert "discipline_list_failed" in caplog.text
    assert "RuntimeError" in caplog.text
    assert product_event_counts()["discipline_list_degraded"] == 1


@pytest.mark.asyncio
async def test_safe_discipline_list_can_fail_open_when_requested():
    repo = _Repo()
    reset_product_event_counts()

    rows = await safe_discipline_list(
        repo,
        "list_broken",
        fail_closed=False,
        limit=10,
    )

    assert rows == []
    assert product_event_counts()["discipline_list_degraded"] == 1

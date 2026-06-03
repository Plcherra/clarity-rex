"""Fail-closed Plaid sync boundary.

This module intentionally contains no Plaid SDK dependency yet. It defines the
server-side service contract so future Plaid work has a focused home instead of
expanding chat, memory, CSV import, or dashboard modules.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal
from typing import Any, Mapping, Sequence


class PlaidSyncError(RuntimeError):
    """Base error for Plaid sync boundary failures."""


class PlaidNotConfiguredError(PlaidSyncError):
    """Raised until a real Plaid client/configuration is injected."""


@dataclass(frozen=True)
class PlaidLinkTokenRequest:
    user_id: str
    client_name: str = "Clarity"
    products: Sequence[str] = ("transactions",)
    country_codes: Sequence[str] = ("US",)
    language: str = "en"


@dataclass(frozen=True)
class PlaidLinkTokenResult:
    link_token: str
    expiration: datetime
    request_id: str | None = None


@dataclass(frozen=True)
class PlaidPublicTokenExchange:
    user_id: str
    public_token: str
    institution_id: str | None = None
    institution_name: str | None = None


@dataclass(frozen=True)
class PlaidItemRecord:
    user_id: str
    item_id: str
    institution_id: str | None
    institution_name: str | None
    status: str
    metadata: Mapping[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class PlaidAccountSnapshot:
    plaid_account_id: str
    name: str
    account_type: str | None = None
    account_subtype: str | None = None
    mask: str | None = None
    current_balance: Decimal | None = None
    available_balance: Decimal | None = None


@dataclass(frozen=True)
class PlaidTransactionSnapshot:
    plaid_transaction_id: str
    plaid_account_id: str
    posted_date: date
    name: str
    amount: Decimal
    pending: bool = False
    merchant_name: str | None = None
    category: Sequence[str] = ()
    metadata: Mapping[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class PlaidSyncResult:
    item_id: str
    accounts_seen: int
    transactions_seen: int
    transactions_inserted: int
    transactions_deduped: int
    status: str
    next_cursor: str | None = None


@dataclass(frozen=True)
class PlaidDisconnectResult:
    item_id: str
    status: str
    disconnected_at: datetime


class PlaidSyncService:
    """Server-side Plaid ingestion facade.

    A real implementation must inject a Plaid client and repositories. Until
    then every public method fails closed so Rex cannot claim a connection,
    reminder, sync, or deletion happened without backend execution.
    """

    async def create_link_token(
        self,
        request: PlaidLinkTokenRequest,
    ) -> PlaidLinkTokenResult:
        self._ensure_user_id(request.user_id)
        raise PlaidNotConfiguredError("Plaid Link token creation is not configured")

    async def exchange_public_token(
        self,
        exchange: PlaidPublicTokenExchange,
    ) -> PlaidItemRecord:
        self._ensure_user_id(exchange.user_id)
        if not exchange.public_token.strip():
            raise PlaidSyncError("Plaid public token is required")
        raise PlaidNotConfiguredError("Plaid public token exchange is not configured")

    async def sync_item(self, *, user_id: str, item_id: str) -> PlaidSyncResult:
        self._ensure_user_id(user_id)
        self._ensure_item_id(item_id)
        raise PlaidNotConfiguredError("Plaid item sync is not configured")

    async def disconnect_item(
        self,
        *,
        user_id: str,
        item_id: str,
    ) -> PlaidDisconnectResult:
        self._ensure_user_id(user_id)
        self._ensure_item_id(item_id)
        raise PlaidNotConfiguredError("Plaid item disconnect is not configured")

    @staticmethod
    def _ensure_user_id(user_id: str) -> None:
        if not user_id.strip():
            raise PlaidSyncError("user_id is required")

    @staticmethod
    def _ensure_item_id(item_id: str) -> None:
        if not item_id.strip():
            raise PlaidSyncError("item_id is required")

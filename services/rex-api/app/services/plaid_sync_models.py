from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Optional


class PlaidSyncServiceError(Exception):
    def __init__(self, detail: str, *, status_code: int = 503) -> None:
        super().__init__(detail)
        self.detail = detail
        self.status_code = status_code


@dataclass(frozen=True)
class PlaidExchangeResult:
    plaid_item_record_id: str
    status: str
    institution_name: Optional[str] = None


@dataclass(frozen=True)
class PlaidItemStatus:
    plaid_item_record_id: str
    status: str
    institution_name: Optional[str] = None
    last_synced_at: Optional[str] = None
    webhook_last_received_at: Optional[str] = None


@dataclass(frozen=True)
class PlaidWebhookResult:
    accepted: bool
    action: str


@dataclass(frozen=True)
class PlaidSyncResult:
    plaid_item_record_id: str
    accounts_synced: int
    transactions_added: int
    transactions_modified: int
    transactions_removed: int
    next_cursor: Optional[str]


def required_string(data: dict[str, Any], key: str) -> str:
    value = data.get(key)
    if not isinstance(value, str) or not value:
        raise PlaidSyncServiceError(
            f"Plaid returned an invalid {key} response.",
            status_code=502,
        )
    return value


def string_or_none(value: Any) -> Optional[str]:
    return value if isinstance(value, str) and value else None


def dict_or_empty(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def list_of_dicts(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]


def number_or_none(value: Any) -> Optional[float]:
    if isinstance(value, (int, float)):
        return float(value)
    return None


def number_or_zero(value: Any) -> float:
    return number_or_none(value) or 0.0


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def first_row(rows: list[dict[str, Any]], detail: str) -> dict[str, Any]:
    if not rows:
        raise PlaidSyncServiceError(detail, status_code=502)
    return rows[0]

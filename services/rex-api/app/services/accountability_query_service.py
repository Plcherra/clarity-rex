"""Read-only accountability queries shared by Rex and the Goals tab."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Awaitable, Callable, Optional

from app.routes.accountability_context_loader import ACCOUNTABILITY_CONTEXT_LIMIT
from app.services.accountability_snapshot import (
    active_plans_for,
    record_display_title,
)


@dataclass(frozen=True)
class AccountabilityInventory:
    active_plans: list[dict]


class AccountabilityQueryService:
    def __init__(
        self,
        memory_service: Any,
        *,
        limit: int = ACCOUNTABILITY_CONTEXT_LIMIT,
    ) -> None:
        self.memory_service = memory_service
        self.limit = limit

    async def list_active_plans(self) -> list[dict]:
        rows = await self._call_list(
            "list_plans",
            active=True,
            status="active",
        )
        return active_plans_for(rows)

    async def load_inventory(self, *, scope: str) -> AccountabilityInventory:
        plans: list[dict] = []
        if scope in {"goals", "both"}:
            plans = await self.list_active_plans()
        return AccountabilityInventory(active_plans=plans)

    def format_inventory_response(
        self,
        *,
        plans: list[dict],
        scope: str,
    ) -> str:
        if scope in {"goals", "both"}:
            if plans:
                lines = "\n".join(
                    f"- {record_display_title(plan)}" for plan in plans
                )
                return f"Active goals:\n{lines}"
            return "You don't have any active goals saved in Clarity."
        return "You don't have any active goals saved in Clarity right now."

    async def _call_list(
        self,
        method_name: str,
        **kwargs: Any,
    ) -> list[dict]:
        method: Optional[Callable[..., Awaitable[list[dict]]]] = getattr(
            self.memory_service,
            method_name,
            None,
        )
        if method is None:
            return []
        kwargs.setdefault("limit", self.limit)
        try:
            rows = await method(**kwargs)
        except TypeError:
            kwargs.pop("status", None)
            try:
                rows = await method(**kwargs)
            except Exception:
                return []
        except Exception:
            return []
        if not isinstance(rows, list):
            return []
        return [row for row in rows if isinstance(row, dict)]

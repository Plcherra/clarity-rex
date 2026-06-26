"""Read-only accountability queries shared by Rex and the Goals tab."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Awaitable, Callable, Optional

from app.routes.accountability_context_loader import ACCOUNTABILITY_CONTEXT_LIMIT
from app.services.accountability_snapshot import (
    active_plans_for,
    open_commitments_for,
    record_display_title,
)


@dataclass(frozen=True)
class AccountabilityInventory:
    active_plans: list[dict]
    open_commitments: list[dict]


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

    async def list_open_commitments(self) -> list[dict]:
        rows = await self._call_list("list_commitments", active=True)
        return open_commitments_for(rows)

    async def load_inventory(self, *, scope: str) -> AccountabilityInventory:
        plans: list[dict] = []
        commitments: list[dict] = []
        if scope in {"goals", "both"}:
            plans = await self.list_active_plans()
        if scope in {"commitments", "both"}:
            commitments = await self.list_open_commitments()
        return AccountabilityInventory(
            active_plans=plans,
            open_commitments=commitments,
        )

    def format_inventory_response(
        self,
        *,
        plans: list[dict],
        commitments: list[dict],
        scope: str,
    ) -> str:
        sections: list[str] = []
        if scope in {"goals", "both"}:
            if plans:
                lines = "\n".join(
                    f"- {record_display_title(plan)}" for plan in plans
                )
                sections.append(f"Active goals:\n{lines}")
            elif scope == "goals":
                sections.append("You don't have any active goals saved in Clarity.")
        if scope in {"commitments", "both"}:
            if commitments:
                lines = "\n".join(
                    f"- {record_display_title(commitment)}"
                    for commitment in commitments
                )
                sections.append(f"Open commitments:\n{lines}")
            elif scope == "commitments":
                sections.append(
                    "You don't have any open commitments saved in Clarity."
                )
        if not sections:
            return (
                "You don't have any active goals or open commitments saved "
                "in Clarity right now."
            )
        return "\n\n".join(sections)

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

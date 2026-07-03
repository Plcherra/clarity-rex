from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Optional

from app.services.insight_generator import (
    GeneratedInsight,
    generate_accountability_insights,
    generate_dashboard_insights,
)
from app.services.insight_repository import InsightRepository
from app.services.memory_errors import MemoryServiceError


@dataclass(frozen=True)
class InsightSyncResult:
    skipped: bool = False
    reason: Optional[str] = None
    created: int = 0
    updated: int = 0
    total_generated: int = 0


class InsightSyncService:
    def __init__(self, repository: InsightRepository) -> None:
        self.repository = repository

    async def sync(
        self,
        *,
        proactive_insights_enabled: bool,
        financial_context: Optional[dict[str, Any]] = None,
        accountability_signals: Optional[list[dict[str, Any]]] = None,
    ) -> InsightSyncResult:
        if not proactive_insights_enabled:
            return InsightSyncResult(skipped=True, reason="opt_in_required")

        generated = self._generate(
            financial_context=financial_context,
            accountability_signals=accountability_signals,
        )
        if not generated:
            return InsightSyncResult(total_generated=0)

        created = 0
        updated = 0
        for insight in generated:
            result = await self.repository.upsert_insight(insight)
            if result == "created":
                created += 1
            elif result == "updated":
                updated += 1

        return InsightSyncResult(
            created=created,
            updated=updated,
            total_generated=len(generated),
        )

    def _generate(
        self,
        *,
        financial_context: Optional[dict[str, Any]],
        accountability_signals: Optional[list[dict[str, Any]]],
    ) -> list[GeneratedInsight]:
        items: list[GeneratedInsight] = []
        period_key = "unknown"
        if financial_context:
            from app.services.insight_generator import _period_key

            period_key = _period_key(financial_context)
            locale = financial_context.get("locale")
            if isinstance(locale, dict):
                locale = locale.get("code")
            items.extend(
                generate_dashboard_insights(
                    financial_context,
                    locale=locale if isinstance(locale, str) else None,
                )
            )
        if accountability_signals:
            locale = None
            if financial_context:
                locale = financial_context.get("locale")
                if isinstance(locale, dict):
                    locale = locale.get("code")
            items.extend(
                generate_accountability_insights(
                    accountability_signals,
                    period_key=period_key,
                    locale=locale if isinstance(locale, str) else None,
                )
            )
        return items

    async def list_insights(self, *, limit: int = 50) -> list[dict[str, Any]]:
        return await self.repository.list_insights(limit=limit)

    async def mark_read(self, insight_id: str) -> Optional[dict[str, Any]]:
        return await self.repository.mark_read(insight_id)

    async def fetch_proactive_enabled(self) -> bool:
        try:
            return await self.repository.fetch_proactive_insights_enabled()
        except MemoryServiceError:
            return False

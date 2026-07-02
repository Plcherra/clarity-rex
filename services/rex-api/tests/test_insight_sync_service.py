import pytest

from app.services.insight_generator import GeneratedInsight, build_insight_fingerprint
from app.services.insight_sync_service import InsightSyncService


class FakeInsightRepository:
    def __init__(self, *, proactive_enabled: bool = False) -> None:
        self.proactive_enabled = proactive_enabled
        self.upserts: list[GeneratedInsight] = []

    async def fetch_proactive_insights_enabled(self) -> bool:
        return self.proactive_enabled

    async def upsert_insight(self, insight: GeneratedInsight) -> str:
        self.upserts.append(insight)
        return "created"


@pytest.mark.asyncio
async def test_sync_upserts_accountability_signals_when_opt_in_enabled():
    repository = FakeInsightRepository(proactive_enabled=True)
    service = InsightSyncService(repository)

    result = await service.sync(
        proactive_insights_enabled=True,
        financial_context={"period": {"reference_month": "2026-07"}},
        accountability_signals=[
            {
                "id": "signal-1",
                "signal_type": "budget_risk",
                "title": "Budget risk",
                "summary": "Housing is over budget.",
                "status": "active",
            }
        ],
    )

    assert result.skipped is False
    assert result.total_generated == 1
    assert repository.upserts[0].source == "accountability"


@pytest.mark.asyncio
async def test_sync_skips_when_opt_in_disabled():
    repository = FakeInsightRepository(proactive_enabled=False)
    service = InsightSyncService(repository)

    result = await service.sync(
        proactive_insights_enabled=False,
        financial_context={"period": {"reference_month": "2026-07"}},
    )

    assert result.skipped is True
    assert result.reason == "opt_in_required"
    assert repository.upserts == []


@pytest.mark.asyncio
async def test_sync_upserts_when_opt_in_enabled():
    repository = FakeInsightRepository(proactive_enabled=True)
    service = InsightSyncService(repository)

    result = await service.sync(
        proactive_insights_enabled=True,
        financial_context={
            "period": {"reference_month": "2026-07"},
            "cash_flow": {
                "income_this_month": 100.0,
                "spent_this_month": 200.0,
                "available_this_month": -100.0,
            },
            "budget": {"period_key": "2026-07", "top_overspending_categories": []},
        },
    )

    assert result.skipped is False
    assert result.total_generated == 1
    assert len(repository.upserts) == 1
    assert repository.upserts[0].fingerprint == build_insight_fingerprint(
        source="dashboard_snapshot",
        insight_type="net_cash_flow",
        period_key="2026-07",
        detail_key="negative",
    )

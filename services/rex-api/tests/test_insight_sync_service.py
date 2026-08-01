import pytest

from app.services.insight_generator import GeneratedInsight, build_insight_fingerprint
from app.services.insight_sync_service import InsightSyncService


class FakeInsightRepository:
    def __init__(self) -> None:
        self.upserts: list[GeneratedInsight] = []

    async def upsert_insight(self, insight: GeneratedInsight) -> str:
        self.upserts.append(insight)
        return "created"


@pytest.mark.asyncio
async def test_sync_upserts_accountability_signals():
    repository = FakeInsightRepository()
    service = InsightSyncService(repository)

    result = await service.sync(
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
async def test_sync_needs_no_opt_in():
    """Insights run for everyone; nothing is hidden behind a preference."""
    repository = FakeInsightRepository()
    service = InsightSyncService(repository)

    result = await service.sync(
        financial_context={
            "period": {"reference_month": "2026-07"},
            "cash_flow": {
                "income_this_month": 100.0,
                "spent_this_month": 200.0,
                "available_this_month": -100.0,
            },
        },
    )

    assert result.skipped is False
    assert result.reason is None
    assert repository.upserts


@pytest.mark.asyncio
async def test_sync_upserts_generated_insights():
    repository = FakeInsightRepository()
    service = InsightSyncService(repository)

    result = await service.sync(
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

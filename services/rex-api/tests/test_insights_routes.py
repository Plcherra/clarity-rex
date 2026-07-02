import pytest
from fastapi.testclient import TestClient

from app.dependencies import get_insight_sync_service
from app.main import app
from app.services.insight_sync_service import InsightSyncResult, InsightSyncService
from app.services.memory_errors import MemoryServiceError


@pytest.fixture
def client():
    app.dependency_overrides.clear()
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


class FakeInsightSyncService:
    def __init__(
        self,
        *,
        list_error: MemoryServiceError | None = None,
        list_rows: list[dict] | None = None,
        proactive_enabled: bool = False,
    ) -> None:
        self.list_error = list_error
        self.list_rows = list_rows or []
        self.proactive_enabled = proactive_enabled
        self.sync_calls: list[dict] = []

    async def list_insights(self, *, limit: int = 50) -> list[dict]:
        if self.list_error is not None:
            raise self.list_error
        return self.list_rows[:limit]

    async def sync(
        self,
        *,
        proactive_insights_enabled: bool,
        financial_context=None,
        accountability_signals=None,
    ) -> InsightSyncResult:
        self.sync_calls.append(
            {
                "proactive_insights_enabled": proactive_insights_enabled,
                "financial_context": financial_context,
                "accountability_signals": accountability_signals,
            }
        )
        if not proactive_insights_enabled:
            return InsightSyncResult(skipped=True, reason="opt_in_required")
        return InsightSyncResult(created=1, total_generated=1)

    async def mark_read(self, insight_id: str):
        return {
            "id": insight_id,
            "fingerprint": "fp-1",
            "source": "dashboard_snapshot",
            "insight_type": "net_cash_flow",
            "title": "Net cash flow",
            "body": "Spending exceeds income.",
            "period_key": "2026-07",
            "payload_json": {},
            "read_at": "2026-07-02T00:00:00Z",
        }

    async def fetch_proactive_enabled(self) -> bool:
        return self.proactive_enabled


def test_list_insights_returns_empty_items(client):
    fake = FakeInsightSyncService()
    app.dependency_overrides[get_insight_sync_service] = lambda: fake

    response = client.get("/insights")

    assert response.status_code == 200
    assert response.json() == {"items": []}


def test_list_insights_storage_unavailable_returns_structured_detail(client):
    fake = FakeInsightSyncService(
        list_error=MemoryServiceError(
            "Insights storage is not available yet.",
            status_code=503,
            error_code="insights_storage_unavailable",
        )
    )
    app.dependency_overrides[get_insight_sync_service] = lambda: fake

    response = client.get("/insights")

    assert response.status_code == 503
    assert response.json()["detail"] == {
        "message": "Insights storage is not available yet.",
        "error_code": "insights_storage_unavailable",
    }


def test_sync_skips_when_opt_in_disabled(client):
    fake = FakeInsightSyncService(proactive_enabled=False)
    app.dependency_overrides[get_insight_sync_service] = lambda: fake

    response = client.post("/insights/sync", json={"financial_context": {}})

    assert response.status_code == 200
    assert response.json()["skipped"] is True
    assert response.json()["reason"] == "opt_in_required"
    assert fake.sync_calls[0]["proactive_insights_enabled"] is False


def test_sync_runs_when_opt_in_enabled(client):
    fake = FakeInsightSyncService(proactive_enabled=True)
    app.dependency_overrides[get_insight_sync_service] = lambda: fake

    response = client.post(
        "/insights/sync",
        json={
            "financial_context": {
                "period": {"reference_month": "2026-07"},
                "cash_flow": {
                    "income_this_month": 0,
                    "spent_this_month": 29.11,
                    "available_this_month": -29.11,
                },
                "budget": {"period_key": "2026-07", "top_overspending_categories": []},
            }
        },
    )

    assert response.status_code == 200
    assert response.json()["skipped"] is False
    assert response.json()["created"] == 1


def test_mark_read_returns_updated_row(client):
    fake = FakeInsightSyncService()
    app.dependency_overrides[get_insight_sync_service] = lambda: fake

    response = client.patch("/insights/insight-1/read")

    assert response.status_code == 200
    assert response.json()["id"] == "insight-1"
    assert response.json()["read_at"] is not None

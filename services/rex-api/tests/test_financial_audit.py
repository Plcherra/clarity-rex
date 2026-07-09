"""Financial audit validation, assistant mapping, and route coverage."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.dependencies import get_clarity_control_service, get_financial_audit_service
from app.main import app
from app.services.clarity_control_service import ClarityControlServiceError
from app.services.clarity_finance_audit import build_assistant_audit_payload
from app.services.financial_audit_service import (
    FinancialAuditValidationError,
    build_audit_event_payload,
)


class FakeFinancialAuditService:
    def __init__(self):
        self.events = []
        self.fail = False

    async def record_event(self, payload):
        if self.fail:
            raise RuntimeError("insert failed")
        self.events.append(payload)

    async def record_event_best_effort(self, payload):
        try:
            await self.record_event(payload)
        except Exception:
            return


class FakeClarityControlService:
    def __init__(self, error=None):
        self.calls = []
        self.error = error

    async def execute(self, action, payload, *, confirmed=False):
        self.calls.append(
            {
                "action": action,
                "payload": payload,
                "confirmed": confirmed,
            }
        )
        if self.error is not None:
            raise self.error
        return [{"id": "transaction-1", "category_id": "category-coffee"}]


@pytest.fixture
def client():
    app.dependency_overrides.clear()
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def test_build_audit_event_rejects_unknown_type():
    with pytest.raises(FinancialAuditValidationError):
        build_audit_event_payload(
            user_id="user-1",
            event_type="forged_event",
            entity_type="transaction",
            source="manual",
        )


def test_build_audit_event_rejects_client_assistant_source():
    with pytest.raises(FinancialAuditValidationError):
        build_audit_event_payload(
            user_id="user-1",
            event_type="budget_created",
            entity_type="budget",
            source="assistant",
            allow_assistant_source=False,
        )


def test_build_audit_event_allows_server_assistant_source():
    payload = build_audit_event_payload(
        user_id="user-1",
        event_type="budget_created",
        entity_type="budget",
        source="assistant",
        allow_assistant_source=True,
        entity_id="budget-1",
    )
    assert payload["source"] == "assistant"
    assert payload["entity_id"] == "budget-1"


def test_assistant_audit_payload_maps_bulk_category_update():
    payload = build_assistant_audit_payload(
        user_id="user-1",
        action="bulk_update_transaction_category",
        payload={"category_id": "category-coffee", "transaction_ids": ["t1", "t2"]},
        result=[{"id": "t1"}, {"id": "t2"}],
    )
    assert payload is not None
    assert payload["event_type"] == "transaction_category_bulk_updated"
    assert payload["source"] == "assistant"
    assert payload["entity_id"] == "t1"


def test_assistant_audit_payload_refines_category_update():
    payload = build_assistant_audit_payload(
        user_id="user-1",
        action="update_transaction",
        payload={"id": "transaction-1", "category_id": "category-coffee"},
        result=[{"id": "transaction-1"}],
    )
    assert payload is not None
    assert payload["event_type"] == "transaction_category_updated"


def test_finance_audit_route_records_validated_event(client):
    fake_audit = FakeFinancialAuditService()
    app.dependency_overrides[get_financial_audit_service] = lambda: fake_audit

    response = client.post(
        "/finance/audit-events",
        json={
            "event_type": "category_renamed",
            "entity_type": "category",
            "entity_id": "category-1",
            "source": "manual",
            "previous_value": {"name": "Old"},
            "new_value": {"name": "New"},
        },
    )

    assert response.status_code == 200
    assert response.json() == {"status": "recorded"}
    assert len(fake_audit.events) == 1
    assert fake_audit.events[0]["event_type"] == "category_renamed"
    assert fake_audit.events[0]["user_id"] == "00000000-0000-0000-0000-000000000001"


def test_finance_audit_route_rejects_forged_assistant_source(client):
    fake_audit = FakeFinancialAuditService()
    app.dependency_overrides[get_financial_audit_service] = lambda: fake_audit

    response = client.post(
        "/finance/audit-events",
        json={
            "event_type": "budget_created",
            "entity_type": "budget",
            "source": "assistant",
        },
    )

    assert response.status_code == 400
    assert fake_audit.events == []


def test_clarity_action_records_assistant_audit(client):
    fake_service = FakeClarityControlService()
    fake_audit = FakeFinancialAuditService()
    app.dependency_overrides[get_clarity_control_service] = lambda: fake_service
    app.dependency_overrides[get_financial_audit_service] = lambda: fake_audit

    response = client.post(
        "/clarity/actions",
        json={
            "action": "update_transaction",
            "confirmed": True,
            "payload": {
                "id": "transaction-1",
                "category_id": "category-coffee",
            },
        },
    )

    assert response.status_code == 200
    assert response.json()["status"] == "applied"
    assert len(fake_audit.events) == 1
    assert fake_audit.events[0]["source"] == "assistant"
    assert fake_audit.events[0]["event_type"] == "transaction_category_updated"


def test_clarity_action_still_applies_when_audit_fails(client):
    fake_service = FakeClarityControlService()
    fake_audit = FakeFinancialAuditService()
    fake_audit.fail = True
    app.dependency_overrides[get_clarity_control_service] = lambda: fake_service
    app.dependency_overrides[get_financial_audit_service] = lambda: fake_audit

    response = client.post(
        "/clarity/actions",
        json={
            "action": "create_budget",
            "confirmed": True,
            "payload": {
                "name": "Groceries",
                "amount": 500,
                "period": "monthly",
                "start_date": "2026-06-01",
            },
        },
    )

    assert response.status_code == 200
    assert response.json()["status"] == "applied"


def test_clarity_action_confirmation_error_skips_audit(client):
    fake_service = FakeClarityControlService(
        error=ClarityControlServiceError(
            "This Clarity action requires explicit confirmation.",
            status_code=428,
        )
    )
    fake_audit = FakeFinancialAuditService()
    app.dependency_overrides[get_clarity_control_service] = lambda: fake_service
    app.dependency_overrides[get_financial_audit_service] = lambda: fake_audit

    response = client.post(
        "/clarity/actions",
        json={
            "action": "delete_transaction",
            "payload": {"id": "transaction-1"},
        },
    )

    assert response.status_code == 428
    assert fake_audit.events == []

from fastapi.testclient import TestClient

from app.dependencies import get_usage_tracking_service
from app.main import app


class FakeUsageTrackingService:
    requested_user_id = None

    async def get_user_voice_usage(self, *, user_id):
        self.requested_user_id = user_id
        return {
            "today_voice_seconds": 60,
            "week_voice_seconds": 180,
            "month_voice_seconds": 240,
            "today_llm_calls": 2,
            "week_llm_calls": 5,
            "month_llm_calls": 7,
        }

    async def get_owner_usage(self, *, requester_user_id):
        assert requester_user_id == "00000000-0000-0000-0000-000000000001"
        return {"authorized": False, "users": []}


class FakeOwnerUsageTrackingService(FakeUsageTrackingService):
    async def get_owner_usage(self, *, requester_user_id):
        return {
            "authorized": True,
            "users": [
                {
                    "user_id": "user-1",
                    "month_voice_seconds": 240,
                    "month_llm_calls": 7,
                    "month_stt_seconds": 210,
                    "month_tts_seconds": 90,
                }
            ],
        }


def test_user_usage_route_returns_current_user_usage():
    service = FakeUsageTrackingService()
    app.dependency_overrides[get_usage_tracking_service] = (
        lambda: service
    )
    with TestClient(app) as client:
        response = client.get("/usage/me")

    assert response.status_code == 200
    assert response.json()["month_voice_seconds"] == 240
    assert service.requested_user_id == "00000000-0000-0000-0000-000000000001"


def test_owner_usage_route_blocks_non_owner():
    app.dependency_overrides[get_usage_tracking_service] = (
        lambda: FakeUsageTrackingService()
    )
    with TestClient(app) as client:
        response = client.get("/usage/admin/users")

    assert response.status_code == 403
    assert response.json()["detail"] == "Owner usage access required."
    assert "users" not in response.json()


def test_owner_usage_route_returns_all_users_for_owner():
    app.dependency_overrides[get_usage_tracking_service] = (
        lambda: FakeOwnerUsageTrackingService()
    )
    with TestClient(app) as client:
        response = client.get("/usage/admin/users")

    assert response.status_code == 200
    assert response.json()["users"][0]["user_id"] == "user-1"

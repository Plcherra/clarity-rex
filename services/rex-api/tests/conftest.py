import pytest

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.main import app
from app.routes import voice_stream as voice_stream_routes


async def fake_current_user():
    return AuthenticatedUser(
        id="00000000-0000-0000-0000-000000000001",
        email="test@example.com",
        access_token="test-access-token",
    )


async def fake_websocket_user(_websocket):
    return await fake_current_user()


class AuthenticatedDependencyOverrides(dict):
    def clear(self):
        super().clear()
        self[get_current_user] = fake_current_user


@pytest.fixture(autouse=True)
def default_authenticated_user(monkeypatch):
    original_overrides = app.dependency_overrides
    overrides = AuthenticatedDependencyOverrides(original_overrides)
    app.dependency_overrides = overrides
    overrides.clear()
    monkeypatch.setattr(
        voice_stream_routes,
        "authenticate_websocket",
        fake_websocket_user,
    )

    yield

    app.dependency_overrides = original_overrides
    app.dependency_overrides.clear()

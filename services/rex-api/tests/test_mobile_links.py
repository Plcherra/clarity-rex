from fastapi.testclient import TestClient

from app.main import app


def test_apple_app_site_association_serves_clarity_plaid_oauth_link():
    with TestClient(app) as client:
        response = client.get("/.well-known/apple-app-site-association")

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("application/json")
    payload = response.json()
    details = payload["applinks"]["details"]
    assert details[0]["appIDs"] == ["7N42NS8B9B.app.goclarity.clarity"]
    assert details[0]["components"][0]["/"] == "/plaid/oauth"

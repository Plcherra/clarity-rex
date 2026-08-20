from app.services.plaid_item_auth_status import (
    item_status_from_plaid_error_code,
    webhook_auth_status,
)


def test_maps_login_required_and_pending_expiration():
    assert item_status_from_plaid_error_code("ITEM_LOGIN_REQUIRED") == (
        "login_required"
    )
    assert item_status_from_plaid_error_code("PENDING_EXPIRATION") == (
        "pending_expiration"
    )
    assert item_status_from_plaid_error_code("RATE_LIMIT_EXCEEDED") is None


def test_webhook_error_payload_uses_nested_error_code():
    assert (
        webhook_auth_status(
            {
                "webhook_type": "ITEM",
                "webhook_code": "ERROR",
                "error": {"error_code": "ITEM_LOGIN_REQUIRED"},
            }
        )
        == "login_required"
    )


def test_webhook_pending_expiration_code():
    assert (
        webhook_auth_status(
            {
                "webhook_type": "ITEM",
                "webhook_code": "PENDING_EXPIRATION",
            }
        )
        == "pending_expiration"
    )

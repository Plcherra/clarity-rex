from app.services.owner_usage_privacy import (
    log_owner_usage_access,
    redact_email,
    redact_owner_users,
)


def test_redact_email_masks_local_part():
    assert redact_email("pedro@example.com") == "p***o@example.com"
    assert redact_email("ab@example.com") == "a*@example.com"
    assert redact_email("a@example.com") == "*@example.com"
    assert redact_email(None) is None
    assert redact_email("not-an-email") is None


def test_redact_owner_users_preserves_usage_fields():
    users = redact_owner_users(
        [
            {
                "user_id": "user-1",
                "email": "owner@goclarity.app",
                "month_llm_calls": 7,
            }
        ]
    )
    assert users[0]["email"] == "o***r@goclarity.app"
    assert users[0]["month_llm_calls"] == 7
    assert users[0]["user_id"] == "user-1"


def test_log_owner_usage_access_is_structured(caplog):
    with caplog.at_level("INFO", logger="rex.owner_usage_audit"):
        log_owner_usage_access(
            endpoint="/usage/admin/users",
            requester_user_id="owner-1",
            authorized=True,
            include_emails=False,
        )

    assert "owner_usage_access" in caplog.text
    assert "owner-1" in caplog.text
    assert "include_emails" in caplog.text

import pytest

from app.config import Settings
from app.services.plaid_config import (
    PlaidConfigurationError,
    get_plaid_config_status,
    require_plaid_configured,
)


def test_missing_plaid_config_fails_closed_without_secret_leaks():
    settings = Settings(plaid_client_id=None, plaid_secret=None)

    status = get_plaid_config_status(settings)
    readiness = status.to_readiness()

    assert status.configured is False
    assert "PLAID_CLIENT_ID" in status.missing
    assert "PLAID_SECRET" in status.missing
    assert readiness["configured"] is False
    assert readiness["required_for_ready"] is False
    assert "secret-value" not in str(readiness)

    with pytest.raises(PlaidConfigurationError, match="PLAID_CLIENT_ID"):
        require_plaid_configured(settings)


def test_sandbox_plaid_config_reports_ready_without_exposing_credentials():
    settings = Settings(
        plaid_client_id="client-id-value",
        plaid_secret="secret-value",
        plaid_environment="sandbox",
        plaid_products="transactions,auth",
        plaid_country_codes="us,ca",
        plaid_ios_bundle_id="com.clarity.app",
    )

    status = get_plaid_config_status(settings)
    readiness = status.to_readiness()

    assert status.configured is True
    assert readiness["configured"] is True
    assert readiness["environment"] == "sandbox"
    assert readiness["products"] == ["transactions", "auth"]
    assert readiness["country_codes"] == ["US", "CA"]
    assert readiness["native"]["ios_bundle_id_configured"] is True
    assert "secret-value" not in str(readiness)
    assert "client-id-value" not in str(readiness)


def test_invalid_plaid_environment_is_not_configured():
    settings = Settings(
        plaid_client_id="client-id-value",
        plaid_secret="secret-value",
        plaid_environment="live",
    )

    status = get_plaid_config_status(settings)

    assert status.configured is False
    assert status.invalid == ("PLAID_ENVIRONMENT",)
    with pytest.raises(PlaidConfigurationError, match="PLAID_ENVIRONMENT"):
        require_plaid_configured(settings)

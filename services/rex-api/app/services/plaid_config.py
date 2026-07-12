from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from app.config import Settings, get_settings


ALLOWED_PLAID_ENVIRONMENTS = {"sandbox", "development", "production"}
REQUIRED_PLAID_ENV_VARS = (
    "PLAID_CLIENT_ID",
    "PLAID_SECRET",
    "PLAID_ENVIRONMENT",
    "PLAID_PRODUCTS",
    "PLAID_COUNTRY_CODES",
)


class PlaidConfigurationError(RuntimeError):
    """Raised when Plaid code is called without complete backend config."""


@dataclass(frozen=True)
class PlaidConfigStatus:
    configured: bool
    environment: str
    products: tuple[str, ...]
    country_codes: tuple[str, ...]
    missing: tuple[str, ...]
    invalid: tuple[str, ...]
    redirect_configured: bool
    webhook_configured: bool
    ios_bundle_id_configured: bool
    android_package_name_configured: bool

    def to_readiness(self, *, required_for_ready: bool = False) -> dict[str, Any]:
        return {
            "configured": self.configured,
            "required_for_ready": required_for_ready,
            "required": list(REQUIRED_PLAID_ENV_VARS),
            "environment": self.environment or "unset",
            "products": list(self.products),
            "country_codes": list(self.country_codes),
            "missing": list(self.missing),
            "invalid": list(self.invalid),
            "redirect_configured": self.redirect_configured,
            "webhook_configured": self.webhook_configured,
            "native": {
                "ios_bundle_id_configured": self.ios_bundle_id_configured,
                "android_package_name_configured": self.android_package_name_configured,
            },
        }


def get_plaid_config_status(settings: Settings | None = None) -> PlaidConfigStatus:
    active_settings = settings or get_settings()
    environment = (active_settings.plaid_environment or "").strip().lower()
    products = _split_csv(active_settings.plaid_products)
    country_codes = _split_csv(active_settings.plaid_country_codes, uppercase=True)

    missing: list[str] = []
    invalid: list[str] = []

    if not _has_value(active_settings.plaid_client_id):
        missing.append("PLAID_CLIENT_ID")
    if not _has_value(active_settings.plaid_secret):
        missing.append("PLAID_SECRET")
    if not environment:
        missing.append("PLAID_ENVIRONMENT")
    elif environment not in ALLOWED_PLAID_ENVIRONMENTS:
        invalid.append("PLAID_ENVIRONMENT")
    if not products:
        missing.append("PLAID_PRODUCTS")
    if not country_codes:
        missing.append("PLAID_COUNTRY_CODES")

    return PlaidConfigStatus(
        configured=not missing and not invalid,
        environment=environment,
        products=products,
        country_codes=country_codes,
        missing=tuple(missing),
        invalid=tuple(invalid),
        redirect_configured=_has_value(active_settings.plaid_redirect_uri),
        webhook_configured=_has_value(active_settings.plaid_webhook_url),
        ios_bundle_id_configured=_has_value(active_settings.plaid_ios_bundle_id),
        android_package_name_configured=_has_value(
            active_settings.plaid_android_package_name
        ),
    )


def require_plaid_configured(settings: Settings | None = None) -> PlaidConfigStatus:
    status = get_plaid_config_status(settings)
    if not status.configured:
        problems = [*status.missing, *status.invalid]
        raise PlaidConfigurationError(
            "Plaid is not configured: " + ", ".join(problems)
        )
    return status


def _split_csv(value: str | None, *, uppercase: bool = False) -> tuple[str, ...]:
    if not value:
        return ()

    items = tuple(item.strip() for item in value.split(",") if item.strip())
    if uppercase:
        return tuple(item.upper() for item in items)
    return items


def _has_value(value: str | None) -> bool:
    return bool(value and value.strip())

"""Optional Sentry initialization for rex-api (env-based DSN only)."""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING

LOGGER = logging.getLogger(__name__)

if TYPE_CHECKING:
    from app.config import Settings


def init_sentry(settings: Settings) -> bool:
    """Initialize Sentry when SENTRY_DSN is set. Returns True if enabled."""
    dsn = (settings.sentry_dsn or "").strip()
    if not dsn:
        LOGGER.info("Sentry disabled (SENTRY_DSN not set).")
        return False

    try:
        import sentry_sdk
        from sentry_sdk.integrations.fastapi import FastApiIntegration
        from sentry_sdk.integrations.starlette import StarletteIntegration
    except ImportError:
        LOGGER.warning("Sentry DSN set but sentry-sdk is not installed.")
        return False

    sentry_sdk.init(
        dsn=dsn,
        environment=settings.app_environment,
        send_default_pii=False,
        traces_sample_rate=settings.sentry_traces_sample_rate,
        integrations=[
            StarletteIntegration(transaction_style="endpoint"),
            FastApiIntegration(transaction_style="endpoint"),
        ],
    )
    LOGGER.info(
        "Sentry enabled environment=%s traces_sample_rate=%s",
        settings.app_environment,
        settings.sentry_traces_sample_rate,
    )
    return True


def capture_exception(error: BaseException) -> None:
    try:
        import sentry_sdk
    except ImportError:
        return
    sentry_sdk.capture_exception(error)

"""Tests for production-safe Grok prompt logging gates."""

from app.config import Settings
from app.services.grok_prompt_logging import (
    grok_prompt_logging_enabled,
    log_grok_prompt_messages,
)


def test_grok_prompt_logging_allowed_in_development_when_flag_true():
    settings = Settings(
        app_environment="development",
        rex_log_grok_prompt=True,
        _env_file=None,
    )
    assert grok_prompt_logging_enabled(settings) is True


def test_grok_prompt_logging_hard_disabled_in_production_even_when_flag_true():
    settings = Settings(
        app_environment="production",
        rex_log_grok_prompt=True,
        _env_file=None,
    )
    assert grok_prompt_logging_enabled(settings) is False


def test_log_grok_prompt_messages_is_noop_in_production(monkeypatch, caplog):
    import app.services.grok_prompt_logging as module

    monkeypatch.setattr(
        module,
        "get_settings",
        lambda: Settings(
            app_environment="production",
            rex_log_grok_prompt=True,
            _env_file=None,
        ),
    )

    with caplog.at_level("INFO", logger="rex.grok_prompt"):
        log_grok_prompt_messages(
            [{"role": "user", "content": "secret user text"}],
            channel="chat",
        )

    assert "grok_prompt" not in caplog.text
    assert "secret user text" not in caplog.text

from app.services.assistant_proposal_settings import (
    AUTO_PROPOSALS_CARD,
    AUTO_PROPOSALS_OFF,
    AUTO_PROPOSALS_TEXT,
    PROPOSAL_KIND_GOALS,
    PROPOSAL_KIND_MEMORY,
    PROPOSAL_KIND_THREADS,
    RESPONSE_STYLE_BALANCED,
    AssistantProposalSettings,
    parse_assistant_settings,
    resolve_assistant_proposal_settings,
)


def test_parse_assistant_settings_defaults_to_card_mode() -> None:
    settings = parse_assistant_settings({})
    assert settings.mode == AUTO_PROPOSALS_CARD
    assert settings.threads is True
    assert settings.goals is True
    assert settings.memory is True
    assert settings.response_style == RESPONSE_STYLE_BALANCED
    assert settings.finance_edits_enabled is True
    assert settings.uses_confirm_cards() is True


def test_parse_assistant_settings_finance_edits_disabled() -> None:
    settings = parse_assistant_settings({"finance_edits_enabled": False})
    assert settings.finance_edits_enabled is False


def test_parse_assistant_settings_off_mode() -> None:
    settings = parse_assistant_settings(
        {
            "auto_proposals_mode": "off",
            "auto_proposals_threads": False,
        }
    )
    assert settings.mode == AUTO_PROPOSALS_OFF
    assert settings.threads is False


def test_parse_assistant_settings_card_mode() -> None:
    settings = parse_assistant_settings({"auto_proposals_mode": "card"})
    assert settings.mode == AUTO_PROPOSALS_CARD
    assert settings.uses_confirm_cards()
    assert not settings.uses_text_offers()


def test_allows_kind_respects_mode_and_toggles() -> None:
    settings = AssistantProposalSettings(
        mode=AUTO_PROPOSALS_TEXT,
        threads=True,
        goals=False,
        memory=True,
    )
    assert settings.allows_kind(PROPOSAL_KIND_THREADS)
    assert not settings.allows_kind(PROPOSAL_KIND_GOALS)
    assert settings.allows_kind(PROPOSAL_KIND_MEMORY)

    card = AssistantProposalSettings(mode=AUTO_PROPOSALS_CARD)
    assert card.allows_kind(PROPOSAL_KIND_THREADS)

    off = AssistantProposalSettings(mode=AUTO_PROPOSALS_OFF)
    assert not off.allows_kind(PROPOSAL_KIND_THREADS)


def test_env_override_auto_proposals_mode(monkeypatch) -> None:
    monkeypatch.setenv("REX_AUTO_PROPOSALS_MODE", "card")
    from app.config import get_settings

    get_settings.cache_clear()
    settings = resolve_assistant_proposal_settings(
        {"auto_proposals_mode": "text"},
        settings=get_settings(),
    )
    assert settings.mode == AUTO_PROPOSALS_CARD
    get_settings.cache_clear()

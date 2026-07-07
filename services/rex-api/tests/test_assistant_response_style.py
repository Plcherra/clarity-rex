from app.services.assistant_proposal_settings import (
    RESPONSE_STYLE_BALANCED,
    RESPONSE_STYLE_CONCISE,
    RESPONSE_STYLE_DETAILED,
)
from app.services.assistant_response_style import (
    effective_response_style,
    max_response_tokens_for_style,
    normalize_response_style,
    requests_detailed_response,
    shift_style_shorter,
)
from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.rex_channel import RexBrainChannel


def test_parse_assistant_settings_default_response_style() -> None:
    from app.services.assistant_proposal_settings import parse_assistant_settings

    settings = parse_assistant_settings({})
    assert settings.response_style == RESPONSE_STYLE_BALANCED


def test_parse_assistant_settings_concise_response_style() -> None:
    from app.services.assistant_proposal_settings import parse_assistant_settings

    settings = parse_assistant_settings({"response_style": "concise"})
    assert settings.response_style == RESPONSE_STYLE_CONCISE


def test_requests_detailed_response() -> None:
    assert requests_detailed_response("Give me the full breakdown please")
    assert requests_detailed_response("Walk me through the budget split")
    assert not requests_detailed_response("What should I do with my paycheck?")


def test_effective_response_style_honors_profile_and_voice() -> None:
    settings = AssistantProposalSettings(response_style=RESPONSE_STYLE_BALANCED)
    assert (
        effective_response_style(
            "hello",
            proposal_settings=settings,
            channel=RexBrainChannel.CHAT,
        )
        == RESPONSE_STYLE_BALANCED
    )
    assert (
        effective_response_style(
            "hello",
            proposal_settings=settings,
            channel=RexBrainChannel.VOICE,
        )
        == RESPONSE_STYLE_CONCISE
    )


def test_effective_response_style_per_turn_detailed_override() -> None:
    settings = AssistantProposalSettings(response_style=RESPONSE_STYLE_CONCISE)
    assert (
        effective_response_style(
            "Give me the full breakdown",
            proposal_settings=settings,
            channel=RexBrainChannel.VOICE,
        )
        == RESPONSE_STYLE_DETAILED
    )


def test_max_response_tokens_for_style() -> None:
    assert max_response_tokens_for_style(RESPONSE_STYLE_CONCISE) == 450
    assert max_response_tokens_for_style(RESPONSE_STYLE_BALANCED) == 1000
    assert max_response_tokens_for_style(RESPONSE_STYLE_DETAILED) == 2000


def test_normalize_and_shift_style() -> None:
    assert normalize_response_style("unknown") == RESPONSE_STYLE_BALANCED
    assert shift_style_shorter(RESPONSE_STYLE_DETAILED) == RESPONSE_STYLE_BALANCED
    assert shift_style_shorter(RESPONSE_STYLE_CONCISE) == RESPONSE_STYLE_CONCISE

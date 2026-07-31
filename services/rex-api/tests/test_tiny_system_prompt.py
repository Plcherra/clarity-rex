from app.services.assistant_proposal_settings import AssistantProposalSettings
from app.services.capability_catalog import CAPABILITY_NAMES, capability_names_prompt
from app.services.grok_turn_brain import GrokTurnBrain
from app.services.tiny_system_prompt import build_tiny_system_prompt


def test_capability_catalog_includes_just_chat() -> None:
    assert "just_chat" in CAPABILITY_NAMES
    assert "create_transaction" not in CAPABILITY_NAMES
    text = capability_names_prompt()
    assert "just_chat" in text
    assert "email" in text.lower()


def test_tiny_system_has_truth_and_gate_no_reply_length() -> None:
    settings = AssistantProposalSettings(mode="card", threads=True, goals=False)
    prompt = build_tiny_system_prompt(settings)
    assert "Truth Rule" in prompt
    assert "Auto Suggestions: card" in prompt
    assert "just_chat" in prompt
    assert "unsupported" in prompt
    assert "rex_action" in prompt
    assert "create_open_thread" in prompt
    assert "MUST append" in prompt
    assert "confirm card" in prompt.lower()
    assert "concise" not in prompt.lower()
    assert "response style" not in prompt.lower()
    assert "persona" not in prompt.lower()


def test_tiny_system_text_requires_title_on_yes() -> None:
    prompt = build_tiny_system_prompt(
        AssistantProposalSettings(mode="text", threads=True)
    )
    assert "non-empty title" in prompt
    assert "say yes to your offer" in prompt.lower()


def test_text_and_card_offer_people_and_moments_not_only_threads() -> None:
    """A hard day with someone is a person note, and the offer must reach it."""
    for mode in ("text", "card"):
        prompt = build_tiny_system_prompt(AssistantProposalSettings(mode=mode))
        assert "save_person" in prompt, mode
        assert "add_person_note" in prompt, mode
        assert "update_person_state" in prompt, mode


def test_off_asks_which_thing_to_save_before_guessing() -> None:
    prompt = build_tiny_system_prompt(AssistantProposalSettings(mode="off"))
    assert "ask which" in prompt.lower()
    assert "a note on their card" in prompt.lower()


def test_tiny_system_off_includes_explicit_mutate_only() -> None:
    prompt = build_tiny_system_prompt(AssistantProposalSettings(mode="off"))
    assert "Auto Suggestions: off" in prompt
    assert "keep chatting always" in prompt.lower()
    assert "explicit" in prompt.lower()
    assert "create_open_thread" in prompt
    assert "update_open_thread" in prompt
    assert '"explicit":true' in prompt or '"explicit": true' in prompt
    assert "can you update it" in prompt.lower()
    assert "short habit label" in prompt.lower()
    assert "never volunteer a save" in prompt.lower()
    assert "When the user wants an open-thread" not in prompt
    assert "coach" not in prompt.lower()


def test_grok_turn_brain_builds_thin_messages() -> None:
    brain = GrokTurnBrain(ai_service=object())
    messages = brain.build_messages(
        user_message="hey",
        recent_messages=[{"role": "assistant", "content": "Hi there"}],
        proposal_settings=AssistantProposalSettings(mode="off"),
        open_thread_titles_block="- Wake up early",
    )
    assert messages[0]["role"] == "system"
    assert "Truth Rule" in messages[0]["content"]
    assert "Wake up early" in messages[0]["content"]
    assert messages[-1] == {"role": "user", "content": "hey"}
    # Rough base size under ~1k tokens (~4 chars/token) for empty-ish thread.
    base_chars = sum(len(item["content"]) for item in messages)
    assert base_chars < 4000

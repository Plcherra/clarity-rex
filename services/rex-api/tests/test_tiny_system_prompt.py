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
    assert "confirm card" in prompt.lower()
    assert "concise" not in prompt.lower()
    assert "response style" not in prompt.lower()
    assert "persona" not in prompt.lower()


def test_tiny_system_off_is_llm_only_no_mutate_instructions() -> None:
    prompt = build_tiny_system_prompt(AssistantProposalSettings(mode="off"))
    assert "Auto Suggestions: off." in prompt
    assert "conversational brain" in prompt.lower()
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

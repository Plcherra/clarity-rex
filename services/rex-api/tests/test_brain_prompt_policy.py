from app.config import get_settings
from app.services.brain_prompt_policy import (
    BRAIN_PROMPT_MODE_RAW,
    BRAIN_PROMPT_MODE_RAW_TRUTH,
    brain_prompt_mode,
    include_action_truth_prompt,
    include_memory_discipline_prompt,
    include_personality_prompt,
    should_append_voice_instructions,
)
from app.services.prompt_service import PromptService
from app.services.voice_stream_config import voice_response_instructions


def test_raw_mode_omits_personality_and_discipline(monkeypatch):
    monkeypatch.setenv("REX_BRAIN_PROMPT_MODE", BRAIN_PROMPT_MODE_RAW)
    get_settings.cache_clear()

    assert brain_prompt_mode() == BRAIN_PROMPT_MODE_RAW
    assert include_personality_prompt() is False
    assert include_action_truth_prompt() is False
    assert include_memory_discipline_prompt() is False

    messages = PromptService().build_messages(user_message="Hello")
    assert messages == [{"role": "user", "content": "Hello"}]


def test_raw_truth_keeps_action_truth_only(monkeypatch):
    monkeypatch.setenv("REX_BRAIN_PROMPT_MODE", BRAIN_PROMPT_MODE_RAW_TRUTH)
    get_settings.cache_clear()

    assert include_action_truth_prompt() is True
    assert include_personality_prompt() is False

    messages = PromptService().build_messages(user_message="Hello")
    assert messages[0]["role"] == "system"
    assert "Action truth policy:" in messages[0]["content"]
    assert "Rex personality" not in messages[0]["content"]


def test_raw_mode_disables_voice_instructions(monkeypatch):
    monkeypatch.setenv("REX_BRAIN_PROMPT_MODE", BRAIN_PROMPT_MODE_RAW)
    monkeypatch.setenv("REX_VOICE_INSTRUCTIONS_ENABLED", "true")
    get_settings.cache_clear()

    assert should_append_voice_instructions() is False
    assert voice_response_instructions() == ""

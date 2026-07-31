"""Knows vocabulary: goals, saved memory, and chat history stay distinguishable."""

from app.services.clarity_knowledge_labels import (
    CLARITY_KNOWLEDGE_LANGUAGE_PROMPT,
    goal_saved_message,
)


def test_goal_saved_message_uses_goal_label():
    assert goal_saved_message("Buy RAM") == "Got it, I added this as a goal: Buy RAM."


def test_clarity_knowledge_language_prompt_distinguishes_memory_and_chat():
    assert "Saved memory" in CLARITY_KNOWLEDGE_LANGUAGE_PROMPT
    assert "Chat history" in CLARITY_KNOWLEDGE_LANGUAGE_PROMPT
    assert "Goal:" in CLARITY_KNOWLEDGE_LANGUAGE_PROMPT

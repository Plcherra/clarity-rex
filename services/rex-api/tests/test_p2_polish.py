from app.services.clarity_knowledge_labels import (
    CLARITY_KNOWLEDGE_LANGUAGE_PROMPT,
    commitment_saved_message,
    goal_saved_message,
)
from app.services.goal_repair_helpers import is_malformed_numbered_goal, split_plan_bodies


def test_goal_saved_message_uses_goal_label():
    assert goal_saved_message("Buy RAM") == "Got it, I added this as a goal: Buy RAM."


def test_commitment_saved_message_uses_commitment_label():
    assert (
        commitment_saved_message("Wake at 5 AM")
        == "Got it, I saved that commitment: Wake at 5 AM."
    )


def test_clarity_knowledge_language_prompt_distinguishes_memory_and_chat():
    assert "Saved memory" in CLARITY_KNOWLEDGE_LANGUAGE_PROMPT
    assert "Chat history" in CLARITY_KNOWLEDGE_LANGUAGE_PROMPT
    assert "Goal:" in CLARITY_KNOWLEDGE_LANGUAGE_PROMPT


def test_malformed_numbered_goal_detects_compound_body():
    plan = {
        "id": "plan-1",
        "title": "PC upgrades",
        "description": "2 goals. 1. Upgrade RAM to 64GB 2. Add 2TB SSD",
    }
    assert is_malformed_numbered_goal(plan) is True
    assert split_plan_bodies(plan) == ["Get RAM to 64GB", "Add 2TB SSD"]

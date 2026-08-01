from app.services.grok_continuing_reply import (
    continuing_reply_for_apply,
    continuing_reply_for_propose,
)


def test_propose_keeps_honest_grok_reply_for_cards() -> None:
    reply = continuing_reply_for_propose(
        "Earlier bedtime is the hard part — what would you cut?",
        surface_client_cards=True,
    )
    assert "earlier bedtime" in reply.lower()
    assert "tap confirm" not in reply.lower()


def test_propose_appends_say_yes_for_text_mode() -> None:
    reply = continuing_reply_for_propose(
        "Earlier bedtime is the hard part.",
        surface_client_cards=False,
    )
    assert "earlier bedtime" in reply.lower()
    assert "say yes" in reply.lower()


def test_propose_scrubs_false_update_claim() -> None:
    reply = continuing_reply_for_propose(
        "I'll update the existing Sleep Schedule thread to 6am.",
        surface_client_cards=True,
    )
    assert "i'll update" not in reply.lower()
    assert "confirm" in reply.lower()
    assert "goals" in reply.lower()


def test_propose_remaps_a_denial_left_over_from_another_guard() -> None:
    reply = continuing_reply_for_propose(
        "I can help, but I don't have a confirmed save from this turn.",
        surface_client_cards=False,
    )
    assert "don't have a confirmed" not in reply.lower()
    assert "say yes" in reply.lower()
    assert "confirm" in reply.lower()
    assert "goals" in reply.lower()


def test_propose_remaps_memory_fallback_to_knows_surface() -> None:
    from app.services.action_truth_memory import UNEXECUTED_MEMORY_FALLBACK

    reply = continuing_reply_for_propose(
        UNEXECUTED_MEMORY_FALLBACK,
        surface_client_cards=True,
        surface="knows",
    )
    assert "knows" in reply.lower()
    assert "goals" not in reply.lower()
    assert "don't have a confirmed" not in reply.lower()


def test_apply_keeps_conversation_and_notes_goals() -> None:
    reply = continuing_reply_for_apply(
        "Shifted the target to 5am.",
        title="Wake at 5am",
    )
    assert "5am" in reply.lower()
    assert "goals" in reply.lower()

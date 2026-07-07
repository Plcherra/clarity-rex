from app.services.write_resolution_continuation import (
    is_write_resolution_ack_turn,
    should_append_companion_continuation,
    should_continue_companion_chat,
    topic_message_for_continuation,
)


def test_should_continue_when_dismissed_proposal_present() -> None:
    turn_result = {
        "response": "Okay, I won't save Europe plan.",
        "memory_changes": {
            "confirmation_required": 0,
            "skipped": 1,
            "write_proposals": [{"id": "proposal-1", "status": "dismissed"}],
        },
    }
    assert should_continue_companion_chat(turn_result) is True


def test_should_not_continue_when_pending_proposal_present() -> None:
    turn_result = {
        "response": "Should I save that?",
        "memory_changes": {
            "confirmation_required": 1,
            "write_proposals": [{"id": "proposal-1", "status": "pending"}],
        },
    }
    assert should_continue_companion_chat(turn_result) is False


def test_is_write_resolution_ack_turn_detects_memory_and_thread_replies() -> None:
    memory_turn = {
        "response": "No problem. I won't save that.",
        "memory_changes": {"skipped": 1},
    }
    thread_turn = {
        "response": "Okay, I won't track that as an open thread.",
        "memory_changes": {},
    }
    offer_turn = {
        "response": "Want me to keep track of this and check in later?",
        "memory_changes": {"confirmation_required": 0},
    }

    assert is_write_resolution_ack_turn(memory_turn) is True
    assert is_write_resolution_ack_turn(thread_turn) is True
    assert is_write_resolution_ack_turn(offer_turn) is False


def test_should_not_append_continuation_after_failed_proposal() -> None:
    turn_result = {
        "response": "I couldn't save that just now.",
        "memory_changes": {
            "write_proposals": [{"id": "proposal-1", "status": "failed"}],
        },
    }
    assert should_append_companion_continuation(turn_result) is False


def test_should_append_continuation_after_successful_apply() -> None:
    turn_result = {
        "response": "Saved milestone under Europe plan.",
        "memory_changes": {
            "created": 1,
            "write_proposals": [{"id": "proposal-1", "status": "applied"}],
        },
    }
    assert should_append_companion_continuation(turn_result) is True


def test_topic_message_for_continuation_uses_prior_user_topic() -> None:
    history = [
        {"role": "user", "content": "I can't sleep and have too much on my mind."},
        {
            "role": "assistant",
            "content": "Want me to keep track of this and check in later?",
        },
    ]
    topic = topic_message_for_continuation(
        history,
        current_message="no",
    )
    assert topic == "I can't sleep and have too much on my mind."

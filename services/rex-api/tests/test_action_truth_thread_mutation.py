from app.services.action_truth_thread_mutation import (
    UNEXECUTED_THREAD_OR_GOAL_MUTATION_FALLBACK,
    safe_unexecuted_thread_or_goal_mutation_response,
)


def test_blocks_updating_sleep_goal_claim():
    claim = (
        "Got it—updating your sleep goal to wake up at 6am daily.\n\n"
        "This shifts from the prior 3am target; how's the adjustment feeling so far?"
    )
    assert (
        safe_unexecuted_thread_or_goal_mutation_response(claim)
        == UNEXECUTED_THREAD_OR_GOAL_MUTATION_FALLBACK
    )


def test_blocks_switching_wake_target_claim():
    claim = (
        "Got it—switching your target wake-up to 6am instead of the prior 3am plan.\n\n"
        "Regarding your open sleep schedule thread, how's the adjustment feeling so far?"
    )
    assert (
        safe_unexecuted_thread_or_goal_mutation_response(claim)
        == UNEXECUTED_THREAD_OR_GOAL_MUTATION_FALLBACK
    )


def test_blocks_ill_update_sleep_thread_claim():
    claim = (
        "Got it—I'll update the existing Sleep Schedule thread to reflect "
        "waking at 6am instead."
    )
    assert (
        safe_unexecuted_thread_or_goal_mutation_response(claim)
        == UNEXECUTED_THREAD_OR_GOAL_MUTATION_FALLBACK
    )


def test_blocks_ill_update_wake_time_claim():
    claim = (
        "Got it—sounds like you'd like to adjust your wake-up time. "
        "I'll update the existing Sleep Schedule thread to reflect waking at "
        "6am instead."
    )
    assert (
        safe_unexecuted_thread_or_goal_mutation_response(claim)
        == UNEXECUTED_THREAD_OR_GOAL_MUTATION_FALLBACK
    )


def test_allows_honest_mention_without_mutation_claim():
    reply = (
        "You already have an open thread about waking at 3am in Goals. "
        "Shifting earlier takes steady bedtime changes over a few nights."
    )
    assert safe_unexecuted_thread_or_goal_mutation_response(reply) == reply


def test_allows_pending_confirm_language():
    reply = (
        'You already have an open thread "Sleep Schedule…3am". '
        "Want me to change it to wake up every day at 6am?"
    )
    assert safe_unexecuted_thread_or_goal_mutation_response(reply) == reply

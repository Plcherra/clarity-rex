from app.services.action_truth_thread_mutation import (
    response_claims_thread_or_goal_mutation_success,
)


def test_detects_updating_sleep_goal_claim():
    claim = (
        "Got it—updating your sleep goal to wake up at 6am daily.\n\n"
        "This shifts from the prior 3am target; how's the adjustment feeling so far?"
    )
    assert response_claims_thread_or_goal_mutation_success(claim)


def test_detects_switching_wake_target_claim():
    claim = (
        "Got it—switching your target wake-up to 6am instead of the prior 3am plan.\n\n"
        "Regarding your open sleep schedule thread, how's the adjustment feeling so far?"
    )
    assert response_claims_thread_or_goal_mutation_success(claim)


def test_detects_ill_update_sleep_thread_claim():
    claim = (
        "Got it—I'll update the existing Sleep Schedule thread to reflect "
        "waking at 6am instead."
    )
    assert response_claims_thread_or_goal_mutation_success(claim)


def test_honest_mention_is_not_a_claim():
    reply = (
        "You already have an open thread about waking at 3am in Goals. "
        "Shifting earlier takes steady bedtime changes over a few nights."
    )
    assert not response_claims_thread_or_goal_mutation_success(reply)


def test_generic_coaching_is_not_a_claim():
    reply = (
        "Updating a wake time works best with a steady bedtime. "
        "What time are you aiming for?"
    )
    assert not response_claims_thread_or_goal_mutation_success(reply)


def test_asking_permission_is_not_a_claim():
    reply = (
        'You already have an open thread "Sleep Schedule…3am". '
        "Want me to change it to wake up every day at 6am?"
    )
    assert not response_claims_thread_or_goal_mutation_success(reply)


def test_past_tense_claim_counts_even_with_confirm_language():
    claim = "I've updated your sleep thread to wake at 6am. Want me to confirm?"
    assert response_claims_thread_or_goal_mutation_success(claim)

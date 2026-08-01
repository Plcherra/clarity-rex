from app.services.action_truth_policy import (
    CHAT_SEARCH_CAPABILITY_FALLBACK,
    DEGRADED_RECALL_FALLBACK,
    EMPTY_RECALL_FALLBACK,
    FILTERED_RECALL_FALLBACK,
    PARTIAL_RECALL_FALLBACK,
    safe_chat_search_capability_response,
    safe_degraded_memory_search_response,
    safe_empty_recall_search_response,
    safe_old_chat_search_response,
    safe_pending_action_response,
    safe_unexecuted_delete_response,
    safe_unexecuted_finance_response,
    safe_unsupported_action_response,
)
from app.services.action_truth_memory import (
    safe_unexecuted_memory_response,
)


def test_canonical_recall_fallbacks_are_not_saved_memory_success_claims():
    from app.services.action_truth_memory import (
        safe_unexecuted_saved_memory_claim_response,
    )

    for fallback in (
        DEGRADED_RECALL_FALLBACK,
        EMPTY_RECALL_FALLBACK,
        FILTERED_RECALL_FALLBACK,
        PARTIAL_RECALL_FALLBACK,
    ):
        assert safe_unexecuted_saved_memory_claim_response(fallback) == fallback


def test_pending_action_success_claim_returns_confirmation_text():
    response = safe_pending_action_response(
        "Done, I moved Starbucks to Coffee.",
        [{"confirmation_text": "Move Starbucks to Coffee?"}],
    )

    assert response == (
        "Move Starbucks to Coffee? "
        "Tap confirm to save — nothing is saved until you confirm."
    )


def test_unsupported_action_success_claim_is_blocked():
    response = safe_unsupported_action_response(
        "Sent. I emailed your mom.",
        ["send_email"],
    )

    assert response == (
        "I can't complete send email from Clarity yet. I can help you think it "
        "through or draft it, but I won't claim it was done."
    )


def test_unexecuted_memory_success_claim_is_blocked():
    response = safe_unexecuted_memory_response("Saved. I updated your city.")

    assert response == (
        "I can help with that, but I don't have a confirmed saved change from this "
        "turn. Tell me the exact fact to save or try again."
    )


def test_unexecuted_memory_saving_claim_is_blocked():
    response = safe_unexecuted_memory_response(
        "Got it--saving your Omen 45L PC now.",
    )

    assert response == (
        "I can help with that, but I don't have a confirmed saved change from this "
        "turn. Tell me the exact fact to save or try again."
    )


def test_saved_memory_claim_without_write_is_blocked_for_unknown_turns():
    from app.services.action_truth_memory import (
        response_claims_saved_memory_success,
        safe_unexecuted_saved_memory_claim_response,
    )

    claim = "Updated your mother's name to Ariadyna in saved memory."
    assert response_claims_saved_memory_success(claim) is True
    response = safe_unexecuted_saved_memory_claim_response(claim)
    assert response == (
        "I can help with that, but I don't have a confirmed saved change from this "
        "turn. Tell me the exact fact to save or try again."
    )


def test_past_tense_knows_claim_scrubbed_even_with_confirm_language():
    from app.services.action_truth_memory import (
        UNEXECUTED_MEMORY_FALLBACK,
        response_claims_saved_memory_success,
        safe_unexecuted_saved_memory_claim_response,
    )

    claim = "I've saved that in Knows. Want me to confirm?"
    assert response_claims_saved_memory_success(claim) is True
    assert safe_unexecuted_saved_memory_claim_response(claim) == UNEXECUTED_MEMORY_FALLBACK


def test_confirm_only_ask_without_past_tense_is_not_memory_success_claim():
    from app.services.action_truth_memory import (
        response_claims_saved_memory_success,
        safe_unexecuted_saved_memory_claim_response,
    )

    reply = "Want me to save that preference in Knows?"
    assert response_claims_saved_memory_success(reply) is False
    assert safe_unexecuted_saved_memory_claim_response(reply) == reply


def test_yes_saved_shorthand_without_write_is_blocked():
    from app.services.action_truth_memory import (
        response_claims_saved_memory_success,
        safe_unexecuted_saved_memory_claim_response,
    )

    claim = "Yes, saved: Marcella is my friend."
    assert response_claims_saved_memory_success(claim) is True
    response = safe_unexecuted_saved_memory_claim_response(claim)
    assert "don't have a confirmed saved change" in response


def test_ill_save_as_goal_claim_is_success_term_for_pending_guard():
    response = safe_pending_action_response(
        "Yes, I'll save 'Pay my bills tomorrow' as a Goal.",
        [{"confirmation_text": "Save Pay my bills tomorrow as a goal?"}],
    )
    assert "Tap confirm to save" in response
    assert "nothing is saved until you confirm" in response


def test_casual_success_without_memory_claim_is_not_blocked_by_saved_memory_guard():
    from app.services.action_truth_memory import (
        safe_unexecuted_saved_memory_claim_response,
    )

    response = safe_unexecuted_saved_memory_claim_response(
        "Got it — sounds like a good night."
    )
    assert response == "Got it — sounds like a good night."


def test_spanish_saved_memory_claim_without_write_is_blocked():
    from app.services.action_truth_memory import (
        response_claims_saved_memory_success,
        safe_unexecuted_saved_memory_claim_response,
    )

    claim = "Lo guardé en la memoria guardada."
    assert response_claims_saved_memory_success(claim) is True
    response = safe_unexecuted_saved_memory_claim_response(claim)
    assert "don't have a confirmed saved change" in response


def test_unexecuted_delete_success_claim_is_blocked():
    response = safe_unexecuted_delete_response(
        "Done, I deleted it.",
        user_message="Can you delete?",
    )

    assert "don't have a confirmed backend delete" in response


def test_unexecuted_delete_guard_skips_non_delete_goals_questions():
    # Inventory phrase detection is stubbed off (plan 04); guard must still
    # leave honest Goals answers alone when the user is not asking to delete.
    response = safe_unexecuted_delete_response(
        "You have one active goal saved: Buy RAM.",
        user_message="What goals do we have saved?",
        conversation_history=None,
    )

    assert response == "You have one active goal saved: Buy RAM."


def test_degraded_recall_uses_canonical_fallback():
    response = safe_degraded_memory_search_response(
        "I don't know anything about your mom.",
        memory_status={"state": "degraded"},
    )

    assert response == DEGRADED_RECALL_FALLBACK


def test_degraded_chat_search_does_not_override_saved_memory_answer():
    response = safe_degraded_memory_search_response(
        "Your saved memory says Jessica works with you.",
        memory_status={"state": "degraded", "saved_knowledge_count": 1},
    )

    assert response == "Your saved memory says Jessica works with you."


def test_empty_chat_search_does_not_override_saved_memory_answer():
    response = safe_empty_recall_search_response(
        "Your saved memory says Jessica works with you.",
        memory_status={
            "saved_knowledge_count": 1,
            "source_statuses": [
                {
                    "source": "chat_search",
                    "attempted": True,
                    "succeeded": True,
                    "status": "empty",
                    "result_count": 0,
                }
            ],
        },
    )

    assert response == "Your saved memory says Jessica works with you."


def test_partial_chat_search_uses_canonical_degraded_fallback():
    response = safe_old_chat_search_response(
        "I checked the old chats and found no mentions of your mom.",
        chat_search_results_loaded=False,
        memory_status={
            "source_statuses": [
                {
                    "source": "chat_search",
                    "attempted": True,
                    "succeeded": True,
                    "partial": True,
                    "result_count": 0,
                }
            ]
        },
    )

    assert response == DEGRADED_RECALL_FALLBACK


def test_loaded_chat_history_no_mentions_claim_uses_partial_fallback():
    response = safe_old_chat_search_response(
        "I checked the old chats and found no mentions of your PC.",
        chat_search_results_loaded=True,
        memory_status={
            "source_statuses": [
                {
                    "source": "chat_search",
                    "attempted": True,
                    "succeeded": True,
                    "status": "found",
                    "result_count": 1,
                }
            ]
        },
    )

    assert response == PARTIAL_RECALL_FALLBACK


def test_chat_no_mentions_claim_without_search_is_blocked():
    response = safe_old_chat_search_response(
        "No mentions of your mom in the chats.",
        chat_search_results_loaded=False,
        memory_status=None,
    )

    assert response == DEGRADED_RECALL_FALLBACK


def test_complete_empty_recall_uses_canonical_no_results_fallback():
    response = safe_empty_recall_search_response(
        "No, I don't have anything about your mom saved.",
        memory_status={
            "source_statuses": [
                {
                    "source": "chat_search",
                    "attempted": True,
                    "succeeded": True,
                    "status": "empty",
                    "result_count": 0,
                }
            ]
        },
    )

    assert response == EMPTY_RECALL_FALLBACK


def test_filtered_only_chat_search_does_not_claim_clean_empty_result():
    response = safe_empty_recall_search_response(
        "No, I don't have anything about your mom saved.",
        memory_status={
            "source_statuses": [
                {
                    "source": "chat_search",
                    "attempted": True,
                    "succeeded": True,
                    "status": "filtered",
                    "filtered_all_matches": True,
                    "raw_match_count": 1,
                    "result_count": 0,
                }
            ]
        },
    )

    assert response == FILTERED_RECALL_FALLBACK


def test_filtered_only_old_chat_no_result_uses_unusable_evidence_fallback():
    response = safe_old_chat_search_response(
        "I checked old chats and found nothing about your mom.",
        chat_search_results_loaded=False,
        memory_status={
            "source_statuses": [
                {
                    "source": "chat_search",
                    "attempted": True,
                    "succeeded": True,
                    "status": "filtered",
                    "filtered_all_matches": True,
                    "raw_match_count": 2,
                    "result_count": 0,
                }
            ]
        },
    )

    assert response == FILTERED_RECALL_FALLBACK


def test_unexecuted_finance_success_claim_is_blocked():
    response = safe_unexecuted_finance_response(
        "Done. I updated your Code AI Tools budget to $250.",
        user_message="Set Code AI Tools budget to $250 per month",
        intent="finance",
    )

    assert "don't have a confirmed change" in response


def test_unexecuted_finance_guard_skips_read_only_finance_questions():
    response = safe_unexecuted_finance_response(
        "You spent $42 on Code AI Tools this month.",
        user_message="How much did I spend on Code AI Tools?",
        intent="finance",
    )

    assert response == "You spent $42 on Code AI Tools this month."


def test_unexecuted_finance_guard_skips_non_finance_intents():
    response = safe_unexecuted_finance_response(
        "Updated your budget.",
        user_message="Set Code AI Tools budget to $250 per month",
        intent="memory_save",
    )

    assert response == "Updated your budget."


def test_fake_current_chat_only_limitation_is_blocked():
    response = safe_chat_search_capability_response(
        "I only search the current chat, so older messages might not show up."
    )

    assert response == CHAT_SEARCH_CAPABILITY_FALLBACK

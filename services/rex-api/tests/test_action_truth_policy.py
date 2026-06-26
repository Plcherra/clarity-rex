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
    safe_unexecuted_goal_response,
    safe_unexecuted_memory_response,
    safe_unsupported_action_response,
)


def test_pending_action_success_claim_returns_confirmation_text():
    response = safe_pending_action_response(
        "Done, I moved Starbucks to Coffee.",
        [{"confirmation_text": "Move Starbucks to Coffee?"}],
    )

    assert response == "Move Starbucks to Coffee?"


def test_unsupported_action_success_claim_is_blocked():
    response = safe_unsupported_action_response(
        "Sent. I emailed your mom.",
        ["send_email"],
    )

    assert response == (
        "I can't complete send email from Clarity yet. I can help you think it "
        "through or draft it, but I won't claim it was done."
    )


def test_unexecuted_goal_guard_skips_goals_inventory_questions():
    response = safe_unexecuted_goal_response(
        "I added it as a goal: Be a goal/commitment.",
        user_message="What goals do we have saved?",
        intent="goal_or_commitment",
    )

    assert response == "I added it as a goal: Be a goal/commitment."


def test_unexecuted_goal_guard_skips_non_goal_intents():
    response = safe_unexecuted_goal_response(
        "I added it as a goal: Buy RAM.",
        user_message="How much did I spend?",
        intent="finance",
    )

    assert response == "I added it as a goal: Buy RAM."


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


def test_unexecuted_delete_success_claim_is_blocked():
    response = safe_unexecuted_delete_response(
        "Done, I deleted it.",
        user_message="Can you delete?",
    )

    assert "don't have a confirmed backend delete" in response


def test_unexecuted_delete_guard_skips_goals_inventory_questions():
    history = [
        {
            "role": "assistant",
            "content": (
                "I couldn't find an active saved memory matching that, so I "
                "didn't delete anything."
            ),
        }
    ]
    response = safe_unexecuted_delete_response(
        "You have one commitment saved: Be a goal/commitment.",
        user_message="What commitments do we have saved?",
        conversation_history=history,
    )

    assert response == "You have one commitment saved: Be a goal/commitment."


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


def test_fake_current_chat_only_limitation_is_blocked():
    response = safe_chat_search_capability_response(
        "I only search the current chat, so older messages might not show up."
    )

    assert response == CHAT_SEARCH_CAPABILITY_FALLBACK

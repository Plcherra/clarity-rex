from app.services.action_truth_policy import (
    CHAT_SEARCH_CAPABILITY_FALLBACK,
    DEGRADED_RECALL_FALLBACK,
    EMPTY_RECALL_FALLBACK,
    safe_chat_search_capability_response,
    safe_degraded_memory_search_response,
    safe_empty_recall_search_response,
    safe_old_chat_search_response,
    safe_pending_action_response,
    safe_unexecuted_delete_response,
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


def test_unexecuted_memory_success_claim_is_blocked():
    response = safe_unexecuted_memory_response("Saved. I updated your city.")

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


def test_degraded_recall_uses_canonical_fallback():
    response = safe_degraded_memory_search_response(
        "I don't know anything about your mom.",
        memory_status={"state": "degraded"},
    )

    assert response == DEGRADED_RECALL_FALLBACK


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
                    "result_count": 0,
                }
            ]
        },
    )

    assert response == EMPTY_RECALL_FALLBACK


def test_fake_current_chat_only_limitation_is_blocked():
    response = safe_chat_search_capability_response(
        "I only search the current chat, so older messages might not show up."
    )

    assert response == CHAT_SEARCH_CAPABILITY_FALLBACK

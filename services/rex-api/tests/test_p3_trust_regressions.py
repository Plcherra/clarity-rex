"""P3 trust regression tests for inventory routing and stream observability."""

from __future__ import annotations

from app.services.action_truth_policy import safe_unexecuted_delete_response
from app.services.chat_turn_observability import ChatTurnObserver
from app.services.goal_command_parsing import is_goals_inventory_query


def test_inventory_query_never_routes_to_delete_clarification_guard():
    message = "What goals do we have saved?"
    assert is_goals_inventory_query(message) is True
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
        "Active goals:\n- Wake at 5 AM",
        user_message=message,
        conversation_history=history,
    )
    assert response == "Active goals:\n- Wake at 5 AM"


def test_stream_turn_trace_records_handler_on_short_circuit():
    observer = ChatTurnObserver()
    trace = observer.new_trace(conversation_id="conv-stream", intent="goal")
    trace.record_handler("goal_command")
    payload = observer.log_turn(trace)
    assert payload["handler"] == "goal_command"
    assert payload["conversation_id"] == "conv-stream"

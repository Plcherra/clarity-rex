from app.services.chat_turn_observability import (
    DURABLE_APPLY_APPLIED,
    DURABLE_APPLY_PENDING,
    ChatTurnObserver,
    ChatTurnTrace,
)


def test_turn_trace_records_handler_and_guard_rewrites():
    trace = ChatTurnTrace(conversation_id="conv-1", intent="memory_recall")
    trace.record_handler("memory_turn")
    trace.record_resolver_target("long_term_memory", "Legacy of Kain")
    trace.record_truth_rewrite("unexecuted_delete")
    trace.duration_ms = 42

    payload = trace.metadata()
    assert payload["handler"] == "memory_turn"
    assert payload["resolver_target_type"] == "long_term_memory"
    assert payload["resolver_target"] == "Legacy of Kain"
    assert payload["truth_guard_rewrites"] == ["unexecuted_delete"]
    assert payload["duration_ms"] == 42
    assert payload["write_proposals_count"] == 0
    assert payload["durable_apply_status"] == "none"


def test_turn_trace_records_proposal_settings_without_message_bodies():
    trace = ChatTurnTrace(conversation_id="conv-3", intent="goal")
    trace.record_proposal_settings(
        profile_mode="text",
        env_mode=None,
        effective_mode="text",
        settings_load_status="ok",
        enabled_proposal_kinds=["threads", "goals", "memory"],
    )
    trace.record_proposal_outcome(
        proposal_kind="open_thread",
        write_proposals_count=1,
        durable_apply_status=DURABLE_APPLY_PENDING,
    )
    payload = trace.metadata()
    assert payload["profile_mode"] == "text"
    assert payload["effective_mode"] == "text"
    assert payload["settings_load_status"] == "ok"
    assert payload["enabled_proposal_kinds"] == ["threads", "goals", "memory"]
    assert payload["proposal_kind"] == "open_thread"
    assert payload["write_proposals_count"] == 1
    assert payload["durable_apply_status"] == DURABLE_APPLY_PENDING
    assert "message" not in payload
    assert "content" not in payload


def test_turn_observer_logs_metadata_only():
    observer = ChatTurnObserver()
    trace = observer.new_trace(conversation_id="conv-2", intent="goal")
    trace.record_handler("goal_command")
    trace.record_proposal_outcome(
        proposal_kind="plan",
        write_proposals_count=0,
        durable_apply_status=DURABLE_APPLY_APPLIED,
    )
    payload = observer.log_turn(trace)
    assert payload["conversation_id"] == "conv-2"
    assert payload["handler"] == "goal_command"
    assert payload["durable_apply_status"] == DURABLE_APPLY_APPLIED

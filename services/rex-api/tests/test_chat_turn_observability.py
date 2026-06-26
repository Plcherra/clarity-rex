from app.services.chat_turn_observability import ChatTurnObserver, ChatTurnTrace


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


def test_turn_observer_logs_metadata_only():
    observer = ChatTurnObserver()
    trace = observer.new_trace(conversation_id="conv-2", intent="goal_or_commitment")
    trace.record_handler("goal_command")
    payload = observer.log_turn(trace)
    assert payload["conversation_id"] == "conv-2"
    assert payload["handler"] == "goal_command"

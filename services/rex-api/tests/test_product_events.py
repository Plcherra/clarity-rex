import json

from app.services.product_events import (
    emit_api_5xx,
    emit_discipline_list_degraded,
    emit_plaid_exchange_result,
    emit_plaid_sync_degraded,
    emit_product_event,
    emit_voice_stream_error,
    emit_write_confirmation_result,
    product_event_counts,
    reset_product_event_counts,
)


def setup_function():
    reset_product_event_counts()


def test_emit_product_event_is_metadata_only(caplog):
    with caplog.at_level("INFO", logger="rex.product_events"):
        payload = emit_product_event(
            "write_confirmation_result",
            result="applied",
            action_type="memory",
            secret_should_not_be_here=None,
        )

    assert payload == {
        "event": "write_confirmation_result",
        "result": "applied",
        "action_type": "memory",
    }
    assert "secret" not in caplog.text
    assert product_event_counts()["write_confirmation_result"] == 1


def test_critical_event_helpers_increment_counters():
    emit_write_confirmation_result(result="failed", action_type="plan")
    emit_voice_stream_error(code="transcription_failed", status_code=502)
    emit_api_5xx(status_code=500, method="POST", path="/chat")
    emit_plaid_exchange_result(result="ok", sync_status="synced")
    emit_plaid_sync_degraded(error_class="PlaidApiClientError", status_code=503)
    emit_discipline_list_degraded(
        operation="list_entities",
        error_class="RuntimeError",
        fail_closed=True,
    )

    counts = product_event_counts()
    assert counts["write_confirmation_result"] == 1
    assert counts["voice_stream_error"] == 1
    assert counts["api_5xx"] == 1
    assert counts["plaid_exchange_result"] == 1
    assert counts["plaid_sync_degraded"] == 1
    assert counts["discipline_list_degraded"] == 1


def test_api_5xx_redacts_uuid_path_segments(caplog):
    with caplog.at_level("INFO", logger="rex.product_events"):
        payload = emit_api_5xx(
            status_code=500,
            method="GET",
            path="/usage/admin/users/c89fa61a-f67e-4454-a4a7-2775adc774c3/daily",
        )

    assert payload["path"] == "/usage/admin/users/:id/daily"
    logged = json.loads(caplog.records[-1].message.split(" ", 1)[1])
    assert logged["path"] == "/usage/admin/users/:id/daily"

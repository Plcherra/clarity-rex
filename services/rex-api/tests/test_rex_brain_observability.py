import json
from pathlib import Path

import pytest

from app.config import Settings
from app.services.rex_brain import RexBrainInput, RexThinkingRouter
from app.services.rex_brain_contracts import RexBrainChannel
from app.services.rex_model_router import RexModelRouter
from app.services.rex_observability import RexBrainObserver


class FakeLogger:
    def __init__(self):
        self.records = []

    def info(self, message, *args):
        self.records.append(message % args)


def _decision(message="Analyze my spending", **kwargs):
    return RexThinkingRouter().route(RexBrainInput(message=message, **kwargs))


def test_observer_logs_metadata_only_without_raw_text_or_financial_rows():
    logger = FakeLogger()
    observer = RexBrainObserver(logger=logger)
    decision = _decision(
        message="Analyze Private Merchant and secret transaction row",
        has_financial_context=True,
    )
    model_route = RexModelRouter(
        Settings(
            grok_model="grok-default",
            grok_reasoning_model="grok-reasoning",
            rex_brain_routing_enabled=True,
            rex_brain_rollout_stage="deep_think_ui",
        )
    ).route_for_decision(decision)

    payload = observer.log_turn(
        request_id="request-1",
        channel=RexBrainChannel.CHAT,
        decision=decision,
        model_route=model_route,
        status="completed",
        duration_ms=123,
    )

    assert payload == {
        "request_id": "request-1",
        "channel": "chat",
        "status": "completed",
        "layer": "layer_2_analytical",
        "model_profile": "reasoning",
        "effective_model_profile": "reasoning",
        "context_budget": "medium",
        "output_mode": "analysis",
        "latency_class": "deep",
        "cost_tier": "high",
        "routing_enabled": True,
        "escalation_source": "analytical_language",
        "reasons": [
            "financial_context_available",
            "analytical_language",
        ],
        "duration_ms": 123,
    }
    rendered = json.dumps(payload) + "\n" + "\n".join(logger.records)
    assert "Private Merchant" not in rendered
    assert "secret transaction" not in rendered
    assert "rex_brain_turn" in logger.records[0]


def test_observer_supports_error_class_without_exception_body():
    observer = RexBrainObserver(logger=FakeLogger())
    decision = _decision(message="hey")
    model_route = RexModelRouter(
        Settings(grok_model="grok-default")
    ).route_for_decision(decision)

    payload = observer.log_turn(
        request_id="request-2",
        channel=RexBrainChannel.VOICE,
        decision=decision,
        model_route=model_route,
        status="failed",
        error_class="AIServiceError",
    )

    assert payload["status"] == "failed"
    assert payload["error_class"] == "AIServiceError"
    assert "detail" not in payload
    assert "message" not in payload


@pytest.mark.parametrize(
    "fixture", json.loads(Path("tests/fixtures/rex_brain_evals.json").read_text())
)
def test_golden_rex_brain_eval_routes(fixture):
    channel = RexBrainChannel(fixture.get("channel", "chat"))
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message=fixture["message"],
            channel=channel,
            has_financial_context=fixture.get("has_financial_context", False),
            has_structured_memory=fixture.get("has_structured_memory", False),
            has_goals=fixture.get("has_goals", False),
            has_pending_commitments=fixture.get("has_pending_commitments", False),
            user_requested_deep_thinking=fixture.get(
                "user_requested_deep_thinking",
                False,
            ),
            user_enabled_proactive_insights=fixture.get(
                "user_enabled_proactive_insights",
                False,
            ),
            user_preference_profile=fixture.get(
                "user_preference_profile",
                "default",
            ),
        )
    )

    assert decision.layer.value == fixture["expected_layer"]
    assert decision.model_profile.value == fixture["expected_profile"]
    metadata = decision.metadata()
    for key, expected in fixture.get("expected_metadata", {}).items():
        if isinstance(expected, dict):
            assert metadata[key] | expected == metadata[key]
        else:
            assert metadata[key] == expected

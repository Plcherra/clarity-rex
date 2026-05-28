import json
import logging
from dataclasses import dataclass
from typing import Optional
from uuid import uuid4

from app.services.rex_brain_contracts import RexBrainChannel, RexBrainDecision
from app.services.rex_model_router import RexModelRoute


@dataclass(frozen=True)
class RexBrainObservation:
    request_id: str
    channel: str
    status: str
    layer: str
    model_profile: str
    effective_model_profile: str
    context_budget: str
    output_mode: str
    latency_class: str
    cost_tier: str
    routing_enabled: bool
    escalation_source: str
    reasons: tuple[str, ...]
    error_class: Optional[str] = None
    duration_ms: Optional[int] = None

    def metadata(self) -> dict:
        payload = {
            "request_id": self.request_id,
            "channel": self.channel,
            "status": self.status,
            "layer": self.layer,
            "model_profile": self.model_profile,
            "effective_model_profile": self.effective_model_profile,
            "context_budget": self.context_budget,
            "output_mode": self.output_mode,
            "latency_class": self.latency_class,
            "cost_tier": self.cost_tier,
            "routing_enabled": self.routing_enabled,
            "escalation_source": self.escalation_source,
            "reasons": list(self.reasons),
        }
        if self.error_class:
            payload["error_class"] = self.error_class
        if self.duration_ms is not None:
            payload["duration_ms"] = self.duration_ms
        return payload


class RexBrainObserver:
    """Metadata-only Rex Brain observability.

    This logger intentionally accepts only decision/model-route objects and
    caller-provided ids/status. It does not accept raw user text, prompt text,
    financial rows, memory bodies, or files.
    """

    def __init__(self, logger: Optional[logging.Logger] = None) -> None:
        self.logger = logger or logging.getLogger("rex.brain")

    def new_request_id(self, prefix: str = "rexbrain") -> str:
        return f"{prefix}-{uuid4().hex[:12]}"

    def observation(
        self,
        *,
        request_id: str,
        channel: RexBrainChannel,
        decision: RexBrainDecision,
        model_route: RexModelRoute,
        status: str,
        error_class: Optional[str] = None,
        duration_ms: Optional[int] = None,
    ) -> RexBrainObservation:
        return RexBrainObservation(
            request_id=request_id,
            channel=channel.value,
            status=status,
            layer=decision.layer.value,
            model_profile=decision.model_profile.value,
            effective_model_profile=model_route.effective_profile.value,
            context_budget=decision.context_budget.value,
            output_mode=decision.output_mode.value,
            latency_class=decision.latency_class.value,
            cost_tier=model_route.cost_tier.value,
            routing_enabled=model_route.routing_enabled,
            escalation_source=decision.escalation_source,
            reasons=tuple(decision.reasons),
            error_class=error_class,
            duration_ms=duration_ms,
        )

    def log_turn(
        self,
        *,
        request_id: str,
        channel: RexBrainChannel,
        decision: RexBrainDecision,
        model_route: RexModelRoute,
        status: str,
        error_class: Optional[str] = None,
        duration_ms: Optional[int] = None,
    ) -> dict:
        observation = self.observation(
            request_id=request_id,
            channel=channel,
            decision=decision,
            model_route=model_route,
            status=status,
            error_class=error_class,
            duration_ms=duration_ms,
        )
        payload = observation.metadata()
        self.logger.info("rex_brain_turn %s", json.dumps(payload, sort_keys=True))
        return payload

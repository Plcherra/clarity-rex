from __future__ import annotations

import time
from typing import Optional

from app.services.ai_service import AIService
from app.services.chat_turn_context import MemoryService
from app.services.grok_usage import GrokUsage
from app.services.rex_channel import RexBrainChannel
from app.services.usage_tracking_service import UsageTrackingService


class ChatUsageRecorder:
    def __init__(
        self,
        *,
        ai_service: AIService,
        memory_service: MemoryService,
        usage_tracking_service: UsageTrackingService,
    ) -> None:
        self.ai_service = ai_service
        self.memory_service = memory_service
        self.usage_tracking_service = usage_tracking_service

    async def record_llm_usage(
        self,
        *,
        channel: RexBrainChannel,
        ai_kwargs: dict,
        latency_ms: int,
        status: str = "success",
        error_class: Optional[str] = None,
        usage: GrokUsage | None = None,
    ) -> None:
        user_id = getattr(self.memory_service, "user_id", None)
        if not user_id:
            return
        prompt_tokens = usage.prompt_tokens if usage else None
        completion_tokens = usage.completion_tokens if usage else None
        token_count = usage.total_tokens if usage and usage.total_tokens > 0 else None
        grok_cost_cents = usage.cost_cents() if usage else None
        await self.usage_tracking_service.record_llm_turn(
            user_id=user_id,
            surface="assistant",
            channel=channel.value,
            model=self._usage_model(ai_kwargs),
            latency_ms=latency_ms,
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            token_count=token_count,
            grok_cost_cents=grok_cost_cents,
            status=status,
            error_class=error_class,
        )

    def elapsed_ms(self, started_at: float) -> int:
        return max(0, round((time.perf_counter() - started_at) * 1000))

    def _usage_model(self, ai_kwargs: dict) -> str:
        model_override = ai_kwargs.get("model_override")
        if isinstance(model_override, str) and model_override.strip():
            return model_override
        settings = getattr(self.ai_service, "settings", None)
        model = getattr(settings, "grok_model", None)
        return model if isinstance(model, str) and model.strip() else "unknown"

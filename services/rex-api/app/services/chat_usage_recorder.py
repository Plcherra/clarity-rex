from __future__ import annotations

import time
from typing import Optional

from app.services.ai_service import AIService
from app.services.chat_turn_context import MemoryService
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
    ) -> None:
        user_id = getattr(self.memory_service, "user_id", None)
        if not user_id:
            return
        await self.usage_tracking_service.record_llm_turn(
            user_id=user_id,
            surface="assistant",
            channel=channel.value,
            model=self._usage_model(ai_kwargs),
            latency_ms=latency_ms,
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

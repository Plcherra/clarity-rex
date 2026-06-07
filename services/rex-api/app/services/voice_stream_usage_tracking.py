from typing import Any, Optional


class VoiceStreamUsageTrackingMixin:
    async def _record_stt_usage(
        self,
        transcription: Optional[dict[str, Any]],
        *,
        latency_ms: int,
        status: str = "success",
        error_class: Optional[str] = None,
    ) -> None:
        if not self.usage_tracking_service or not self.user_id:
            return
        await self.usage_tracking_service.record_stt_turn(
            user_id=self.user_id,
            duration_ms=self._transcription_duration_ms(transcription),
            latency_ms=latency_ms,
            model=self._deepgram_model(),
            status=status,
            error_class=error_class,
        )

    async def _record_voice_session_usage(
        self,
        duration_ms: int,
        *,
        status: str = "completed",
    ) -> None:
        if not self.usage_tracking_service or not self.user_id:
            return
        await self.usage_tracking_service.record_voice_session(
            user_id=self.user_id,
            duration_ms=duration_ms,
            status=status,
        )

    def _transcription_duration_ms(
        self,
        transcription: Optional[dict[str, Any]],
    ) -> Optional[int]:
        if not transcription:
            return None
        value = transcription.get("duration_seconds")
        if not isinstance(value, (int, float)):
            return None
        return max(0, round(float(value) * 1000))

    def _deepgram_model(self) -> str:
        settings = getattr(self.deepgram_streaming_service, "settings", None)
        model = getattr(settings, "deepgram_model", None)
        return model if isinstance(model, str) and model.strip() else "unknown"

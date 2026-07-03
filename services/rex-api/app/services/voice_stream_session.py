import asyncio
import contextlib
import logging
import time
from typing import Any, Optional

from fastapi import WebSocket

from app.services.chat_service import ChatService
from app.services.deepgram_streaming_service import DeepgramStreamingService
from app.services.google_tts_service import GoogleTTSService
from app.services.memory_service import MemoryServiceError
from app.services.usage_tracking_service import UsageTrackingService
from app.services.voice_stream_event_router import VoiceStreamEventRouterMixin
from app.services.voice_stream_live_transcription import (
    VoiceStreamLiveTranscriptionMixin,
)
from app.services.voice_stream_response_writer import VoiceStreamResponseWriterMixin
from app.services.voice_stream_turn_processing import VoiceStreamTurnProcessingMixin
from app.services.voice_stream_usage_tracking import VoiceStreamUsageTrackingMixin
from app.services.voice_stream_config import (
    VOICE_DEEP_RESPONSE_MAX_TOKENS,
    VOICE_RESPONSE_INSTRUCTIONS,
    VOICE_RESPONSE_MAX_TOKENS,
    voice_response_max_tokens,
)


LOGGER = logging.getLogger("rex.voice_stream")


class VoiceStreamSession(
    VoiceStreamEventRouterMixin,
    VoiceStreamTurnProcessingMixin,
    VoiceStreamUsageTrackingMixin,
    VoiceStreamResponseWriterMixin,
    VoiceStreamLiveTranscriptionMixin,
):
    def __init__(
        self,
        websocket: WebSocket,
        deepgram_streaming_service: DeepgramStreamingService,
        chat_service: ChatService,
        google_tts_service: GoogleTTSService,
        usage_tracking_service: Optional[UsageTrackingService] = None,
        user_id: Optional[str] = None,
    ) -> None:
        self.websocket = websocket
        self.deepgram_streaming_service = deepgram_streaming_service
        self.chat_service = chat_service
        self.google_tts_service = google_tts_service
        self.usage_tracking_service = usage_tracking_service
        self.user_id = user_id
        self.conversation_id: Optional[str] = None
        self.financial_context: Optional[dict[str, Any]] = None
        self.write_confirmation: Optional[dict[str, Any]] = None
        self.input_mime_type = "audio/linear16"
        self.sample_rate = 16000
        self.client = ""
        self._session_id = f"voice-{time.time_ns()}"
        self._audio_chunks: list[bytes] = []
        self._audio_started_at: Optional[float] = None
        self._audio_bytes = 0
        self._audio_chunks_received = 0
        self._active_turn_task: Optional[asyncio.Task[None]] = None
        self._live_transcription: Optional[Any] = None
        self._live_endpoint_task: Optional[asyncio.Task[None]] = None
        self._last_live_transcript_at: Optional[float] = None
        self._turn_audio_bytes = 0
        self._turn_audio_chunks = 0
        self._send_lock = asyncio.Lock()
        self._active_tts_tasks: set[asyncio.Task[Any]] = set()
        self._active_audio_flush_tasks: set[asyncio.Task[Any]] = set()
        self._assistant_audio_started = False
        self._turn_generation = 0
        self.locale: Optional[str] = None

    async def _cancel_active_turn(self) -> None:
        task = self._active_turn_task
        if task is None or task.done():
            self._active_turn_task = None
            await self._cancel_active_tts_tasks()
            return
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task
        self._active_turn_task = None
        await self._cancel_active_tts_tasks()

    async def _interrupt_active_turn(self, *, reason: str) -> None:
        self._turn_generation += 1
        self._assistant_audio_started = False
        self._audio_chunks.clear()
        self._audio_started_at = None
        self._audio_bytes = 0
        self._audio_chunks_received = 0
        await self._cancel_live_endpoint_check()
        await self._close_live_transcription()
        await self._cancel_active_turn()
        await self._send_event(
            "session.interrupted",
            session_id=self._session_id,
            reason=reason,
        )
        LOGGER.info(
            "voice_turn_interrupted session_id=%s conversation_id=%s reason=%s",
            self._session_id,
            self.conversation_id,
            reason,
        )

    async def _cancel_active_tts_tasks(self) -> None:
        tasks = list(self._active_tts_tasks | self._active_audio_flush_tasks)
        if not tasks:
            return
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        self._active_tts_tasks.clear()
        self._active_audio_flush_tasks.clear()

    async def _send_event(self, event: str, **payload: Any) -> None:
        async with self._send_lock:
            await self.websocket.send_json({"event": event, **payload})

    async def _send_error(
        self,
        message: str,
        status_code: int = 400,
        code: str = "voice_stream_error",
    ) -> None:
        await self._send_event(
            "error",
            code=code,
            detail=message,
            status_code=status_code,
        )

    async def _send_turn_error(self, error: Exception) -> None:
        from app.services.ai_service import AIServiceError
        from app.services.chat_service import ConversationNotFoundError
        from app.services.deepgram_service import DeepgramServiceError
        from app.services.google_tts_service import GoogleTTSServiceError

        if isinstance(error, DeepgramServiceError):
            await self._send_error(
                error.detail,
                status_code=error.status_code,
                code="transcription_failed",
            )
            return
        if isinstance(error, ConversationNotFoundError):
            await self._send_error(
                "Conversation not found.",
                status_code=404,
                code="conversation_not_found",
            )
            return
        if isinstance(error, AIServiceError):
            await self._send_error(
                error.detail,
                status_code=error.status_code,
                code="assistant_planning_failed",
            )
            return
        if isinstance(error, MemoryServiceError):
            await self._send_error(
                error.detail,
                status_code=error.status_code,
                code="memory_context_failed",
            )
            return
        if isinstance(error, GoogleTTSServiceError):
            await self._send_error(
                error.detail,
                status_code=error.status_code,
                code="tts_failed",
            )
            return
        await self._send_error("Voice stream failed.", status_code=500)

    def _log_unexpected_error(self, error: Exception) -> None:
        LOGGER.exception(
            "voice_stream_failed session_id=%s conversation_id=%s client=%s "
            "input_mime_type=%s sample_rate=%s audio_bytes=%s "
            "audio_chunks=%s live_transcription=%s error_class=%s",
            self._session_id,
            self.conversation_id,
            self.client,
            self.input_mime_type,
            self.sample_rate,
            self._audio_bytes,
            self._audio_chunks_received,
            self._live_transcription is not None,
            error.__class__.__name__,
        )

    def _elapsed_ms(self, start_time: float) -> int:
        return max(0, round((time.perf_counter() - start_time) * 1000))

    def websocket_json_loads(self, text: str) -> dict[str, Any]:
        import json

        data = json.loads(text)
        if not isinstance(data, dict):
            raise ValueError("Expected object")
        return data

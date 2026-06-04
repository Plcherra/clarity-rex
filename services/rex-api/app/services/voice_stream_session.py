import asyncio
import contextlib
import logging
import time
from typing import Any, Optional

from fastapi import WebSocket, WebSocketDisconnect

from app.services.ai_service import AIServiceError
from app.services.chat_service import ChatService, ConversationNotFoundError
from app.services.deepgram_service import DeepgramServiceError
from app.services.deepgram_streaming_service import DeepgramStreamingService
from app.services.google_tts_service import GoogleTTSService, GoogleTTSServiceError
from app.services.memory_service import MemoryServiceError
from app.services.voice_stream_config import (
    VOICE_DEEP_RESPONSE_MAX_TOKENS,
    VOICE_RESPONSE_INSTRUCTIONS,
    VOICE_RESPONSE_MAX_TOKENS,
    voice_response_max_tokens,
)
from app.services.voice_stream_live_transcription import (
    VoiceStreamLiveTranscriptionMixin,
)
from app.services.voice_stream_response_writer import VoiceStreamResponseWriterMixin


LOGGER = logging.getLogger("rex.voice_stream")


class VoiceStreamSession(
    VoiceStreamResponseWriterMixin,
    VoiceStreamLiveTranscriptionMixin,
):
    def __init__(
        self,
        websocket: WebSocket,
        deepgram_streaming_service: DeepgramStreamingService,
        chat_service: ChatService,
        google_tts_service: GoogleTTSService,
    ) -> None:
        self.websocket = websocket
        self.deepgram_streaming_service = deepgram_streaming_service
        self.chat_service = chat_service
        self.google_tts_service = google_tts_service
        self.conversation_id: Optional[str] = None
        self.financial_context: Optional[dict[str, Any]] = None
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

    async def run(self) -> None:
        await self.websocket.accept()

        try:
            while True:
                message = await self.websocket.receive()
                if message.get("type") == "websocket.disconnect":
                    break

                if message.get("bytes") is not None:
                    await self._receive_audio_chunk(message["bytes"])
                    continue

                text = message.get("text")
                if text is None:
                    continue

                should_continue = await self._receive_text_event(text)
                if not should_continue:
                    break
        except WebSocketDisconnect:
            return
        finally:
            await self._cancel_live_endpoint_check()
            await self._cancel_active_turn()

    async def _receive_audio_chunk(self, chunk: bytes) -> None:
        if not chunk:
            return
        if self._active_turn_task is not None and not self._active_turn_task.done():
            return
        self._audio_bytes += len(chunk)
        self._audio_chunks_received += 1
        if self._audio_started_at is None:
            self._audio_started_at = time.perf_counter()
        if self._supports_live_transcription():
            live_transcription = await self._ensure_live_transcription()
            await live_transcription.send_audio(chunk)
        else:
            self._audio_chunks.append(chunk)
        await self._send_event(
            "audio.received",
            bytes_received=self._audio_bytes_received(),
            chunk_count=self._audio_chunk_count(),
        )

    async def _receive_text_event(self, text: str) -> bool:
        try:
            payload = self.websocket_json_loads(text)
        except ValueError:
            await self._send_error("Invalid voice stream event.")
            return True

        event = payload.get("event")
        if event == "session.start":
            self.conversation_id = payload.get("conversation_id") or self.conversation_id
            financial_context = payload.get("financial_context")
            if isinstance(financial_context, dict):
                self.financial_context = financial_context
            self.input_mime_type = payload.get("input_mime_type") or self.input_mime_type
            self.client = str(payload.get("client") or self.client or "")
            sample_rate = payload.get("sample_rate")
            if isinstance(sample_rate, int) and sample_rate > 0:
                self.sample_rate = sample_rate
            await self._send_event(
                "session.started",
                session_id=self._session_id,
                conversation_id=self.conversation_id,
                input_mime_type=self.input_mime_type,
                sample_rate=self.sample_rate,
            )
            return True

        if event == "utterance.end":
            if self._active_turn_task is not None and not self._active_turn_task.done():
                await self._send_error(
                    "Rex is still answering the previous voice turn.",
                    status_code=409,
                    code="turn_in_progress",
                )
                return True
            await self._cancel_live_endpoint_check()
            if self._live_transcription is not None:
                self._active_turn_task = asyncio.create_task(
                    self._process_live_utterance()
                )
            else:
                self._active_turn_task = asyncio.create_task(self._process_utterance())
            return True

        if event == "user.interrupt":
            self._audio_chunks.clear()
            self._audio_started_at = None
            await self._cancel_live_endpoint_check()
            await self._close_live_transcription()
            await self._cancel_active_turn()
            await self._send_event("session.interrupted", session_id=self._session_id)
            return True

        if event == "session.end":
            await self._cancel_active_turn()
            await self._cancel_live_endpoint_check()
            await self._close_live_transcription()
            await self._send_event("session.ended", session_id=self._session_id)
            await self.websocket.close()
            return False

        await self._send_error(f"Unsupported voice stream event: {event}")
        return True

    async def _process_utterance(self) -> None:
        chunks = self._audio_chunks
        self._audio_chunks = []
        audio_started_at = self._audio_started_at
        self._audio_started_at = None
        self._turn_audio_bytes = self._audio_bytes_received()
        self._turn_audio_chunks = self._audio_chunk_count()
        self._audio_bytes = 0
        self._audio_chunks_received = 0

        if not chunks:
            await self._send_error("I did not catch any audio.", code="empty_audio")
            return

        timings: dict[str, int] = {}
        started_at = time.perf_counter()
        if audio_started_at is not None:
            timings["capture_ms"] = self._elapsed_ms(audio_started_at)

        try:
            transcription = await self.deepgram_streaming_service.transcribe_audio_stream(
                self._chunk_iterator(chunks),
                content_type=self.input_mime_type,
                sample_rate=self.sample_rate,
                on_transcript=self._send_transcript_event,
            )
            timings["stt_ms"] = self._elapsed_ms(started_at)

            await self._send_event(
                "transcript.final",
                transcript=transcription["transcript"],
                confidence=transcription.get("confidence"),
                metadata=transcription.get("metadata") or {},
            )

            await self._send_event("assistant.started")
            response_text = await self._stream_chat_and_audio(
                transcription["transcript"],
                transcription,
                timings,
            )
            timings["turn_ms"] = self._elapsed_ms(started_at)
            self._log_turn_timings(timings, mode="buffered")
            await self._send_event(
                "assistant.done",
                conversation_id=self.conversation_id,
                response_text=response_text,
                memory_changes=getattr(self, "_last_memory_changes", None),
                timings=timings,
            )
        except (
            DeepgramServiceError,
            ConversationNotFoundError,
            AIServiceError,
            MemoryServiceError,
            GoogleTTSServiceError,
        ) as error:
            await self._send_turn_error(error)
        except asyncio.CancelledError:
            raise
        except Exception as error:
            self._log_unexpected_error(error)
            await self._send_error("Voice stream failed.", status_code=500)
        finally:
            current_task = asyncio.current_task()
            if self._active_turn_task is current_task:
                self._active_turn_task = None

    async def _process_live_utterance(self) -> None:
        await self._cancel_live_endpoint_check()
        live_transcription = self._live_transcription
        self._live_transcription = None
        audio_started_at = self._audio_started_at
        self._audio_started_at = None
        self._turn_audio_bytes = self._audio_bytes_received()
        self._turn_audio_chunks = self._audio_chunk_count()
        self._audio_bytes = 0
        self._audio_chunks_received = 0

        if live_transcription is None:
            await self._send_error("I did not catch any audio.", code="empty_audio")
            return

        timings: dict[str, int] = {}
        started_at = time.perf_counter()
        if audio_started_at is not None:
            timings["capture_ms"] = self._elapsed_ms(audio_started_at)

        try:
            transcription = await live_transcription.finish()
            timings["stt_ms"] = self._elapsed_ms(started_at)
            await self._send_event("assistant.started")
            response_text = await self._stream_chat_and_audio(
                transcription["transcript"],
                transcription,
                timings,
            )
            timings["turn_ms"] = self._elapsed_ms(started_at)
            self._log_turn_timings(timings, mode="live")
            await self._send_event(
                "assistant.done",
                conversation_id=self.conversation_id,
                response_text=response_text,
                memory_changes=getattr(self, "_last_memory_changes", None),
                timings=timings,
            )
        except (
            DeepgramServiceError,
            ConversationNotFoundError,
            AIServiceError,
            MemoryServiceError,
            GoogleTTSServiceError,
        ) as error:
            await self._send_turn_error(error)
        except asyncio.CancelledError:
            raise
        except Exception as error:
            self._log_unexpected_error(error)
            await self._send_error("Voice stream failed.", status_code=500)
        finally:
            current_task = asyncio.current_task()
            if self._active_turn_task is current_task:
                self._active_turn_task = None

    def _audio_bytes_received(self) -> int:
        if self._supports_live_transcription():
            return self._audio_bytes
        return sum(len(item) for item in self._audio_chunks)

    def _audio_chunk_count(self) -> int:
        if self._supports_live_transcription():
            return self._audio_chunks_received
        return len(self._audio_chunks)

    def _log_turn_timings(self, timings: dict[str, int], *, mode: str) -> None:
        LOGGER.info(
            "voice_turn_timing session_id=%s conversation_id=%s client=%s "
            "mode=%s capture_ms=%s stt_ms=%s grok_first_token_ms=%s "
            "tts_first_audio_ms=%s turn_ms=%s audio_bytes=%s audio_chunks=%s",
            self._session_id,
            self.conversation_id,
            self.client,
            mode,
            timings.get("capture_ms"),
            timings.get("stt_ms"),
            timings.get("grok_first_token_ms"),
            timings.get("tts_first_audio_ms"),
            timings.get("turn_ms"),
            self._turn_audio_bytes,
            self._turn_audio_chunks,
        )

    async def _cancel_active_turn(self) -> None:
        task = self._active_turn_task
        if task is None or task.done():
            self._active_turn_task = None
            return
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task
        self._active_turn_task = None

    async def _send_event(self, event: str, **payload: Any) -> None:
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

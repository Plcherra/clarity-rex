"""Buffered and live utterance processing for voice stream sessions."""

from __future__ import annotations

import asyncio
import logging
import time
from typing import Any, Optional

from app.services.ai_service import AIServiceError
from app.services.chat_service import ConversationNotFoundError
from app.services.deepgram_service import DeepgramServiceError
from app.services.google_tts_service import GoogleTTSServiceError
from app.services.memory_service import MemoryServiceError


LOGGER = logging.getLogger("rex.voice_stream")


class VoiceStreamTurnProcessingMixin:
    _session_id: str
    conversation_id: Optional[str]
    input_mime_type: str
    sample_rate: int
    _active_turn_task: Optional[asyncio.Task[None]]
    _live_transcription: Optional[Any]
    _assistant_audio_started: bool
    _turn_generation: int
    _audio_chunks: list[bytes]
    _audio_started_at: Optional[float]
    _audio_bytes: int
    _audio_chunks_received: int
    _turn_audio_bytes: int
    _turn_audio_chunks: int
    client_transcript: Optional[str]
    _last_streamed_transcript: Optional[str]
    deepgram_streaming_service: Any

    def _take_fallback_transcript(self) -> str:
        for candidate in (self.client_transcript, self._last_streamed_transcript):
            text = str(candidate or "").strip()
            if text:
                self.client_transcript = None
                self._last_streamed_transcript = None
                return text
        self.client_transcript = None
        self._last_streamed_transcript = None
        return ""

    async def _process_utterance(self) -> None:
        self._turn_generation += 1
        turn_generation = self._turn_generation
        self._assistant_audio_started = False
        chunks = self._audio_chunks
        self._audio_chunks = []
        audio_started_at = self._audio_started_at
        self._audio_started_at = None
        self._turn_audio_bytes = self._audio_bytes_received()
        self._turn_audio_chunks = self._audio_chunk_count()
        self._audio_bytes = 0
        self._audio_chunks_received = 0

        if not chunks:
            LOGGER.info(
                "voice_empty_audio_recovered session_id=%s conversation_id=%s "
                "mode=buffered",
                self._session_id,
                self.conversation_id,
            )
            await self._send_error("I did not catch any audio.", code="empty_audio")
            return

        timings: dict[str, int] = {}
        started_at = time.perf_counter()
        if audio_started_at is not None:
            timings["capture_ms"] = self._elapsed_ms(audio_started_at)
        LOGGER.info(
            "voice_turn_accepted session_id=%s conversation_id=%s mode=buffered "
            "audio_bytes=%s audio_chunks=%s",
            self._session_id,
            self.conversation_id,
            self._turn_audio_bytes,
            self._turn_audio_chunks,
        )

        try:
            transcription = await self.deepgram_streaming_service.transcribe_audio_stream(
                self._chunk_iterator(chunks),
                content_type=self.input_mime_type,
                sample_rate=self.sample_rate,
                on_transcript=self._send_transcript_event,
            )
            timings["stt_ms"] = self._elapsed_ms(started_at)
            await self._record_stt_usage(
                transcription,
                latency_ms=timings["stt_ms"],
            )
            transcript = str(transcription.get("transcript") or "").strip()
            if not transcript:
                LOGGER.info(
                    "voice_blank_transcript_recovered session_id=%s "
                    "conversation_id=%s mode=buffered",
                    self._session_id,
                    self.conversation_id,
                )
                await self._send_error("I did not catch any audio.", code="empty_audio")
                return
            transcription = {**transcription, "transcript": transcript}

            await self._send_event(
                "transcript.final",
                transcript=transcript,
                confidence=transcription.get("confidence"),
                metadata=transcription.get("metadata") or {},
            )

            await self._send_event("assistant.started")
            response_text = await self._stream_chat_and_audio(
                transcript,
                transcription,
                timings,
                turn_generation=turn_generation,
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
            if isinstance(error, DeepgramServiceError):
                await self._record_stt_usage(
                    None,
                    latency_ms=self._elapsed_ms(started_at),
                    status="failure",
                    error_class=error.__class__.__name__,
                )
            await self._send_turn_error(error)
        except asyncio.CancelledError:
            raise
        except Exception as error:
            self._log_unexpected_error(error)
            await self._send_error("Voice stream failed.", status_code=500)
        finally:
            self._assistant_audio_started = False
            current_task = asyncio.current_task()
            if self._active_turn_task is current_task:
                self._active_turn_task = None

    async def _process_live_utterance(self) -> None:
        self._turn_generation += 1
        turn_generation = self._turn_generation
        self._assistant_audio_started = False
        await self._cancel_live_endpoint_check()
        live_transcription = self._live_transcription
        self._live_transcription = None
        audio_started_at = self._audio_started_at
        self._audio_started_at = None
        self._turn_audio_bytes = self._audio_bytes_received()
        self._turn_audio_chunks = self._audio_chunk_count()
        self._audio_bytes = 0
        self._audio_chunks_received = 0
        # Capture explicit utterance.end.transcript before fallback consume —
        # that string is display authority for flutter_streaming / ios_native.
        explicit_client_transcript = str(self.client_transcript or "").strip()
        fallback_transcript = self._take_fallback_transcript()

        timings: dict[str, int] = {}
        started_at = time.perf_counter()
        if audio_started_at is not None:
            timings["capture_ms"] = self._elapsed_ms(audio_started_at)
        LOGGER.info(
            "voice_turn_accepted session_id=%s conversation_id=%s mode=live "
            "audio_bytes=%s audio_chunks=%s has_live_stt=%s has_fallback=%s "
            "has_client_transcript=%s",
            self._session_id,
            self.conversation_id,
            self._turn_audio_bytes,
            self._turn_audio_chunks,
            live_transcription is not None,
            bool(fallback_transcript),
            bool(explicit_client_transcript),
        )

        try:
            transcription: dict[str, Any]
            if live_transcription is None:
                if not fallback_transcript:
                    LOGGER.info(
                        "voice_empty_audio_recovered session_id=%s "
                        "conversation_id=%s mode=live",
                        self._session_id,
                        self.conversation_id,
                    )
                    await self._send_error(
                        "I did not catch any audio.", code="empty_audio"
                    )
                    return
                transcription = {
                    "transcript": fallback_transcript,
                    "confidence": None,
                    "duration_seconds": None,
                    "metadata": {"transport": "client-transcript-fallback"},
                }
            else:
                try:
                    transcription = await live_transcription.finish()
                except DeepgramServiceError as error:
                    if not fallback_transcript:
                        raise
                    LOGGER.info(
                        "voice_stt_finish_fallback session_id=%s "
                        "conversation_id=%s detail=%s",
                        self._session_id,
                        self.conversation_id,
                        getattr(error, "detail", error),
                    )
                    transcription = {
                        "transcript": fallback_transcript,
                        "confidence": None,
                        "duration_seconds": None,
                        "metadata": {"transport": "client-transcript-fallback"},
                    }
            timings["stt_ms"] = self._elapsed_ms(started_at)
            await self._record_stt_usage(
                transcription,
                latency_ms=timings["stt_ms"],
            )
            deepgram_transcript = str(transcription.get("transcript") or "").strip()
            # Display == brain: when the client finalized a bubble and sent it on
            # utterance.end, that text wins over Deepgram segment join (sticky /
            # drift). Deepgram remains the fallback when the client sent none.
            if explicit_client_transcript:
                if (
                    deepgram_transcript
                    and deepgram_transcript != explicit_client_transcript
                ):
                    LOGGER.info(
                        "voice_client_transcript_authority session_id=%s "
                        "conversation_id=%s deepgram_chars=%s client_chars=%s",
                        self._session_id,
                        self.conversation_id,
                        len(deepgram_transcript),
                        len(explicit_client_transcript),
                    )
                transcript = explicit_client_transcript
            else:
                transcript = deepgram_transcript or fallback_transcript
            if not transcript:
                LOGGER.info(
                    "voice_blank_transcript_recovered session_id=%s "
                    "conversation_id=%s mode=live",
                    self._session_id,
                    self.conversation_id,
                )
                await self._send_error("I did not catch any audio.", code="empty_audio")
                return
            transcription = {**transcription, "transcript": transcript}
            await self._send_event("assistant.started")
            response_text = await self._stream_chat_and_audio(
                transcript,
                transcription,
                timings,
                turn_generation=turn_generation,
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
            if isinstance(error, DeepgramServiceError):
                await self._record_stt_usage(
                    None,
                    latency_ms=self._elapsed_ms(started_at),
                    status="failure",
                    error_class=error.__class__.__name__,
                )
            await self._send_turn_error(error)
        except asyncio.CancelledError:
            raise
        except Exception as error:
            self._log_unexpected_error(error)
            await self._send_error("Voice stream failed.", status_code=500)
        finally:
            self._assistant_audio_started = False
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
        turn_trace = getattr(self, "_last_turn_trace", {}) or {}
        LOGGER.info(
            "voice_turn_timing session_id=%s conversation_id=%s client=%s "
            "mode=%s capture_ms=%s stt_ms=%s grok_first_token_ms=%s "
            "tts_first_audio_ms=%s tts_chunk_count=%s tts_total_ms=%s "
            "turn_ms=%s audio_bytes=%s audio_chunks=%s intent=%s "
            "context_flags=%s memory_action=%s",
            self._session_id,
            self.conversation_id,
            self.client,
            mode,
            timings.get("capture_ms"),
            timings.get("stt_ms"),
            timings.get("grok_first_token_ms"),
            timings.get("tts_first_audio_ms"),
            timings.get("tts_chunk_count", 0),
            timings.get("tts_total_ms"),
            timings.get("turn_ms"),
            self._turn_audio_bytes,
            self._turn_audio_chunks,
            turn_trace.get("intent", "unknown"),
            turn_trace.get("loaded_context", {}),
            turn_trace.get("memory_action", "unknown"),
        )

import asyncio
import logging
import time
from collections.abc import AsyncIterator
from dataclasses import dataclass
from typing import Any, Optional

from app.services.google_tts_service import estimate_tts_duration_ms
from app.services.rex_channel import RexBrainChannel
from app.services.voice_stream_config import (
    voice_response_instructions,
    voice_response_max_tokens,
)
from app.services.voice_stream_orchestrator_support import voice_delay_audio_until_done

_MIN_SPEAKABLE_CHUNK_CHARS = 12
_MIN_SINGLE_SENTENCE_CHUNK_CHARS = 20
_MAX_SPEAKABLE_CHUNK_CHARS = 140


LOGGER = logging.getLogger("rex.voice_stream")


@dataclass
class _PendingVoiceAudioChunk:
    text: str
    task: asyncio.Task[dict[str, Any]]


class VoiceStreamResponseWriterMixin:
    async def _stream_chat_and_audio(
        self,
        transcript: str,
        transcription: dict[str, Any],
        timings: dict[str, int],
        *,
        turn_generation: int,
    ) -> str:
        response_parts: list[str] = []
        speech_buffer = ""
        final_response_text = ""
        delay_audio_until_done = False
        first_token_at: Optional[float] = None
        first_audio_at: Optional[float] = None
        user_message_id: Optional[str] = None
        assistant_message_id: Optional[str] = None
        messages: list[dict[str, Any]] = []
        memory_changes: Optional[dict[str, Any]] = None
        self._last_memory_changes = None
        self._last_turn_trace = {}
        chat_started_at = time.perf_counter()
        pending_audio_chunks: list[_PendingVoiceAudioChunk] = []
        audio_send_lock = asyncio.Lock()
        audio_flush_tasks: set[asyncio.Task[Any]] = set()
        last_audio_sent_at: Optional[float] = None

        def queue_audio_chunk(text: str) -> None:
            task = asyncio.create_task(
                self._synthesize_audio_chunk(text, timings),
            )
            active_tts_tasks = getattr(self, "_active_tts_tasks", None)
            if isinstance(active_tts_tasks, set):
                active_tts_tasks.add(task)
                task.add_done_callback(active_tts_tasks.discard)
            pending_audio_chunks.append(
                _PendingVoiceAudioChunk(
                    text=text,
                    task=task,
                )
            )
            task.add_done_callback(lambda _: schedule_ready_audio_flush())

        def schedule_ready_audio_flush() -> None:
            task = asyncio.create_task(flush_ready_audio_chunks())
            audio_flush_tasks.add(task)
            task.add_done_callback(audio_flush_tasks.discard)
            active_audio_flush_tasks = getattr(
                self,
                "_active_audio_flush_tasks",
                None,
            )
            if isinstance(active_audio_flush_tasks, set):
                active_audio_flush_tasks.add(task)
                task.add_done_callback(active_audio_flush_tasks.discard)

        async def flush_ready_audio_chunks() -> None:
            try:
                await send_ready_audio_chunks(block=False)
            except asyncio.CancelledError:
                return
            except Exception:
                # The main streaming path awaits pending chunks too, where errors
                # are surfaced through the normal turn error handling.
                return

        async def send_ready_audio_chunks(*, block: bool) -> None:
            nonlocal first_audio_at, last_audio_sent_at
            async with audio_send_lock:
                while pending_audio_chunks:
                    if not self._is_current_voice_turn(turn_generation):
                        return
                    pending = pending_audio_chunks[0]
                    if not block and not pending.task.done():
                        return
                    synthesis = await pending.task
                    if not self._is_current_voice_turn(turn_generation):
                        return
                    pending_audio_chunks.pop(0)
                    now = time.perf_counter()
                    if last_audio_sent_at is not None:
                        gap_ms = self._elapsed_ms(last_audio_sent_at)
                        timings["tts_last_chunk_gap_ms"] = gap_ms
                        timings["tts_max_chunk_gap_ms"] = max(
                            timings.get("tts_max_chunk_gap_ms", 0),
                            gap_ms,
                        )
                    last_audio_sent_at = now
                    if first_audio_at is None:
                        first_audio_at = now
                        timings["tts_first_audio_turn_ms"] = self._elapsed_ms(
                            chat_started_at
                        )
                    await self._send_audio_chunk_event(
                        pending.text,
                        synthesis,
                        turn_generation=turn_generation,
                    )

        async for event in self.chat_service.stream_message(
            transcript,
            conversation_id=self.conversation_id,
            response_instructions=voice_response_instructions(
                getattr(self, "locale", None),
            ),
            max_response_tokens=voice_response_max_tokens(transcript),
            financial_context=self.financial_context,
            channel=RexBrainChannel.VOICE,
            include_turn_trace=True,
            locale=getattr(self, "locale", None),
            write_confirmation=getattr(self, "write_confirmation", None),
        ):
            event_name = event.get("event")
            if event_name == "conversation":
                self.conversation_id = event.get("conversation_id") or self.conversation_id
                await self._send_event(
                    "conversation.updated",
                    conversation_id=self.conversation_id,
                )
            elif event_name == "turn.trace":
                self._last_turn_trace = self._safe_turn_trace(event)
                delay_audio_until_done = voice_delay_audio_until_done(
                    str(event.get("intent") or "")
                )
            elif event_name == "token":
                token = str(event.get("token") or "")
                if not token:
                    continue
                if first_token_at is None:
                    first_token_at = time.perf_counter()
                    timings["grok_first_token_ms"] = self._elapsed_ms(chat_started_at)
                response_parts.append(token)
                await self._send_event("assistant.token", token=token)
                if not delay_audio_until_done:
                    speech_buffer += token
                    chunk, speech_buffer = self._next_speakable_chunk(speech_buffer)
                    if chunk:
                        queue_audio_chunk(chunk)
                    await send_ready_audio_chunks(block=False)
            elif event_name == "done":
                self.conversation_id = event.get("conversation_id") or self.conversation_id
                final_response_text = str(event.get("response") or "").strip()
                messages = event.get("messages") or []
                memory_changes = event.get("memory_changes")
                user_message_id, assistant_message_id = self._message_ids(messages)

        streamed_text = "".join(response_parts).strip()
        response_text = final_response_text or streamed_text
        if delay_audio_until_done and response_text:
            queue_audio_chunk(response_text)
        elif (
            final_response_text
            and final_response_text != streamed_text
            and first_audio_at is None
        ):
            queue_audio_chunk(final_response_text)
        elif speech_buffer.strip():
            queue_audio_chunk(speech_buffer.strip())
        await send_ready_audio_chunks(block=True)
        if audio_flush_tasks:
            await asyncio.gather(*audio_flush_tasks, return_exceptions=True)

        await self._send_event(
            "messages.updated",
            conversation_id=self.conversation_id,
            messages=messages,
            memory_changes=memory_changes,
        )
        self._last_memory_changes = memory_changes

        async def persist_voice_metadata() -> None:
            try:
                record = await self.chat_service.save_voice_turn_metadata(
                    conversation_id=self.conversation_id or "",
                    user_message_id=user_message_id,
                    assistant_message_id=assistant_message_id,
                    transcript_confidence=transcription.get("confidence"),
                    audio_duration_seconds=transcription.get("duration_seconds"),
                    input_mime_type=self.input_mime_type,
                    output_audio_encoding=None,
                    metadata={
                        "stt": transcription.get("metadata") or {},
                        "stream": {"session_id": self._session_id, "timings": timings},
                    },
                )
            except Exception:
                LOGGER.exception(
                    "voice_metadata_save_failed session_id=%s conversation_id=%s",
                    self._session_id,
                    self.conversation_id,
                )
                return
            if record and self._is_current_voice_turn(turn_generation):
                await self._send_event(
                    "voice.metadata.saved",
                    conversation_id=self.conversation_id,
                    voice_metadata={"record": record},
                )

        asyncio.create_task(persist_voice_metadata())
        self._last_turn_trace = {
            **self._last_turn_trace,
            "memory_action": self._memory_action(memory_changes),
            "tts_chunk_count": timings.get("tts_chunk_count", 0),
        }
        return response_text

    async def _synthesize_audio_chunk(
        self,
        text: str,
        timings: dict[str, int],
    ) -> dict[str, Any]:
        from app.services.locale_utils import locale_to_tts_code

        synthesis_started_at = time.perf_counter()
        try:
            synthesis = await self.google_tts_service.synthesize_speech(
                text,
                language_code=locale_to_tts_code(getattr(self, "locale", None)),
            )
        except Exception as error:
            await self._record_tts_usage(
                latency_ms=self._elapsed_ms(synthesis_started_at),
                status="failure",
                error_class=error.__class__.__name__,
            )
            raise
        latency_ms = self._elapsed_ms(synthesis_started_at)
        timings["tts_chunk_count"] = timings.get("tts_chunk_count", 0) + 1
        timings["tts_total_ms"] = timings.get("tts_total_ms", 0) + latency_ms
        timings["tts_last_chunk_synthesis_ms"] = latency_ms
        timings["tts_max_chunk_synthesis_ms"] = max(
            timings.get("tts_max_chunk_synthesis_ms", 0),
            latency_ms,
        )
        await self._record_tts_usage(
            duration_ms=estimate_tts_duration_ms(text),
            latency_ms=latency_ms,
            model=synthesis.get("voice_name"),
            character_count=len(text.strip()),
        )
        if "tts_first_audio_ms" not in timings:
            timings["tts_first_audio_ms"] = latency_ms
        return synthesis

    async def _send_audio_chunk_event(
        self,
        text: str,
        synthesis: dict[str, Any],
        *,
        turn_generation: int,
    ) -> None:
        if not self._is_current_voice_turn(turn_generation):
            return
        await self._send_event(
            "assistant.audio_chunk",
            text=text,
            audio_content_type=synthesis["audio_content_type"],
            audio_base64=synthesis["audio_base64"],
            audio_encoding=synthesis["audio_encoding"],
            voice_name=synthesis["voice_name"],
            language_code=synthesis["language_code"],
            metadata=synthesis.get("metadata") or {},
        )
        if self._is_current_voice_turn(turn_generation):
            self._assistant_audio_started = True

    def _is_current_voice_turn(self, turn_generation: int) -> bool:
        return getattr(self, "_turn_generation", turn_generation) == turn_generation

    def _safe_turn_trace(self, event: dict[str, Any]) -> dict[str, Any]:
        return {
            "intent": event.get("intent") or "unknown",
            "channel": event.get("channel") or "voice",
            "loaded_context": event.get("loaded_context") or {},
        }

    def _memory_action(self, memory_changes: Optional[dict[str, Any]]) -> str:
        if not memory_changes:
            return "none"
        if memory_changes.get("updated"):
            return "direct_updated"
        if memory_changes.get("created"):
            return "direct_saved"
        if memory_changes.get("skipped"):
            return "skipped"
        return "none"

    async def _send_transcript_event(self, event: dict[str, Any]) -> None:
        if event.get("event") == "transcript.partial":
            await self._send_event(
                "transcript.partial",
                transcript=event.get("transcript") or "",
                confidence=event.get("confidence"),
                metadata=event.get("metadata") or {},
            )
        elif event.get("event") == "transcript.final":
            await self._send_event(
                "transcript.final",
                transcript=event.get("transcript") or "",
                confidence=event.get("confidence"),
                speech_final=bool(event.get("speech_final")),
                metadata=event.get("metadata") or {},
            )

    def _next_speakable_chunk(self, text: str) -> tuple[Optional[str], str]:
        stripped = text.strip()
        if not stripped:
            return None, ""

        for index, character in enumerate(text):
            if character in ".!?;\n" and index >= _MIN_SPEAKABLE_CHUNK_CHARS:
                chunk = text[: index + 1].strip()
                if character in ".!?" and len(chunk) < _MIN_SINGLE_SENTENCE_CHUNK_CHARS:
                    continue
                rest = text[index + 1 :]
                return chunk, rest

        if len(stripped) >= _MAX_SPEAKABLE_CHUNK_CHARS:
            split_at = text.rfind(" ", 0, _MAX_SPEAKABLE_CHUNK_CHARS)
            if split_at < _MIN_SPEAKABLE_CHUNK_CHARS:
                split_at = _MAX_SPEAKABLE_CHUNK_CHARS
            return text[:split_at].strip(), text[split_at:]

        return None, text

    def _message_ids(self, messages: list[dict[str, Any]]) -> tuple[Optional[str], Optional[str]]:
        user_message_id = None
        assistant_message_id = None
        for message in messages:
            if message.get("role") == "user":
                user_message_id = message.get("id") or user_message_id
            elif message.get("role") == "assistant":
                assistant_message_id = message.get("id") or assistant_message_id
        return user_message_id, assistant_message_id

    async def _chunk_iterator(self, chunks: list[bytes]) -> AsyncIterator[bytes]:
        for chunk in chunks:
            yield chunk

    async def _record_tts_usage(
        self,
        *,
        duration_ms: Optional[int] = None,
        latency_ms: int,
        model: Optional[str] = None,
        character_count: Optional[int] = None,
        status: str = "success",
        error_class: Optional[str] = None,
    ) -> None:
        usage_tracking_service = getattr(self, "usage_tracking_service", None)
        user_id = getattr(self, "user_id", None)
        if not usage_tracking_service or not user_id:
            return
        await usage_tracking_service.record_tts_turn(
            user_id=user_id,
            duration_ms=duration_ms,
            latency_ms=latency_ms,
            model=model or self._google_tts_model(),
            character_count=character_count,
            status=status,
            error_class=error_class,
        )

    def _google_tts_model(self) -> str:
        settings = getattr(self.google_tts_service, "settings", None)
        model = getattr(settings, "google_tts_voice_name", None)
        return model if isinstance(model, str) and model.strip() else "unknown"

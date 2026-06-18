import time
from collections.abc import AsyncIterator
from typing import Any, Optional

from app.services.google_tts_service import estimate_tts_duration_ms
from app.services.rex_brain_contracts import RexBrainChannel
from app.services.voice_stream_config import (
    VOICE_RESPONSE_INSTRUCTIONS,
    voice_response_max_tokens,
)

_MIN_SPEAKABLE_CHUNK_CHARS = 36
_MAX_SPEAKABLE_CHUNK_CHARS = 140


class VoiceStreamResponseWriterMixin:
    async def _stream_chat_and_audio(
        self,
        transcript: str,
        transcription: dict[str, Any],
        timings: dict[str, int],
    ) -> str:
        response_parts: list[str] = []
        speech_buffer = ""
        first_token_at: Optional[float] = None
        first_audio_at: Optional[float] = None
        user_message_id: Optional[str] = None
        assistant_message_id: Optional[str] = None
        messages: list[dict[str, Any]] = []
        memory_changes: Optional[dict[str, Any]] = None
        self._last_memory_changes = None
        self._last_turn_trace = {}
        chat_started_at = time.perf_counter()

        async for event in self.chat_service.stream_message(
            transcript,
            conversation_id=self.conversation_id,
            response_instructions=VOICE_RESPONSE_INSTRUCTIONS,
            max_response_tokens=voice_response_max_tokens(transcript),
            financial_context=self.financial_context,
            channel=RexBrainChannel.VOICE,
            include_turn_trace=True,
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
            elif event_name == "token":
                token = str(event.get("token") or "")
                if not token:
                    continue
                if first_token_at is None:
                    first_token_at = time.perf_counter()
                    timings["grok_first_token_ms"] = self._elapsed_ms(chat_started_at)
                response_parts.append(token)
                speech_buffer += token
                await self._send_event("assistant.token", token=token)
                chunk, speech_buffer = self._next_speakable_chunk(speech_buffer)
                if chunk:
                    first_audio_at = await self._synthesize_and_send_audio_chunk(
                        chunk,
                        timings,
                        first_audio_at,
                    )
            elif event_name == "done":
                self.conversation_id = event.get("conversation_id") or self.conversation_id
                messages = event.get("messages") or []
                memory_changes = event.get("memory_changes")
                user_message_id, assistant_message_id = self._message_ids(messages)

        response_text = "".join(response_parts).strip()
        if speech_buffer.strip():
            first_audio_at = await self._synthesize_and_send_audio_chunk(
                speech_buffer.strip(),
                timings,
                first_audio_at,
            )

        metadata_record = await self.chat_service.save_voice_turn_metadata(
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
        await self._send_event(
            "messages.updated",
            conversation_id=self.conversation_id,
            messages=messages,
            memory_changes=memory_changes,
            voice_metadata={"record": metadata_record} if metadata_record else {},
        )
        self._last_memory_changes = memory_changes
        self._last_turn_trace = {
            **self._last_turn_trace,
            "memory_action": self._memory_action(memory_changes),
            "tts_chunk_count": timings.get("tts_chunk_count", 0),
        }
        return response_text

    async def _synthesize_and_send_audio_chunk(
        self,
        text: str,
        timings: dict[str, int],
        first_audio_at: Optional[float],
    ) -> Optional[float]:
        synthesis_started_at = time.perf_counter()
        try:
            synthesis = await self.google_tts_service.synthesize_speech(text)
        except Exception as error:
            await self._record_tts_usage(
                latency_ms=self._elapsed_ms(synthesis_started_at),
                status="failure",
                error_class=error.__class__.__name__,
            )
            raise
        timings["tts_chunk_count"] = timings.get("tts_chunk_count", 0) + 1
        timings["tts_total_ms"] = timings.get("tts_total_ms", 0) + self._elapsed_ms(
            synthesis_started_at
        )
        await self._record_tts_usage(
            duration_ms=estimate_tts_duration_ms(text),
            latency_ms=self._elapsed_ms(synthesis_started_at),
            model=synthesis.get("voice_name"),
        )
        if first_audio_at is None:
            first_audio_at = time.perf_counter()
            timings["tts_first_audio_ms"] = self._elapsed_ms(synthesis_started_at)

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
        return first_audio_at

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
            status=status,
            error_class=error_class,
        )

    def _google_tts_model(self) -> str:
        settings = getattr(self.google_tts_service, "settings", None)
        model = getattr(settings, "google_tts_voice_name", None)
        return model if isinstance(model, str) and model.strip() else "unknown"

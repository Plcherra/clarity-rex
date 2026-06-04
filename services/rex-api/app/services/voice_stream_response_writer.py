import time
from collections.abc import AsyncIterator
from typing import Any, Optional

from app.services.rex_brain_contracts import RexBrainChannel
from app.services.voice_stream_config import (
    VOICE_RESPONSE_INSTRUCTIONS,
    voice_response_max_tokens,
)


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
        chat_started_at = time.perf_counter()

        async for event in self.chat_service.stream_message(
            transcript,
            conversation_id=self.conversation_id,
            response_instructions=VOICE_RESPONSE_INSTRUCTIONS,
            max_response_tokens=voice_response_max_tokens(transcript),
            financial_context=self.financial_context,
            channel=RexBrainChannel.VOICE,
        ):
            event_name = event.get("event")
            if event_name == "conversation":
                self.conversation_id = event.get("conversation_id") or self.conversation_id
                await self._send_event(
                    "conversation.updated",
                    conversation_id=self.conversation_id,
                )
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
        return response_text

    async def _synthesize_and_send_audio_chunk(
        self,
        text: str,
        timings: dict[str, int],
        first_audio_at: Optional[float],
    ) -> Optional[float]:
        synthesis_started_at = time.perf_counter()
        synthesis = await self.google_tts_service.synthesize_speech(text)
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
            if character in ".!?;\n" and index >= 28:
                chunk = text[: index + 1].strip()
                rest = text[index + 1 :]
                return chunk, rest

        if len(stripped) >= 140:
            split_at = text.rfind(" ", 0, 140)
            if split_at < 45:
                split_at = 140
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

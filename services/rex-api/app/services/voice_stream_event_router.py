"""WebSocket event routing for voice stream sessions."""

from __future__ import annotations

import asyncio
import logging
import time
from typing import Any, Optional


LOGGER = logging.getLogger("rex.voice_stream")


class VoiceStreamEventRouterMixin:
    websocket: Any
    conversation_id: Optional[str]
    input_mime_type: str
    sample_rate: int
    client: str
    locale: Optional[str]
    financial_context: Optional[dict[str, Any]]
    write_confirmation: Optional[dict[str, Any]]
    _session_id: str
    _active_turn_task: Optional[asyncio.Task[None]]
    _live_transcription: Optional[Any]
    _assistant_audio_started: bool
    _audio_bytes: int
    _audio_chunks_received: int
    _audio_started_at: Optional[float]
    _audio_chunks: list[bytes]

    async def run(self) -> None:
        from fastapi import WebSocketDisconnect

        await self.websocket.accept()
        session_started_at = time.perf_counter()
        session_status = "completed"

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
        except Exception:
            session_status = "failure"
            raise
        finally:
            await self._cancel_live_endpoint_check()
            await self._cancel_active_turn()
            await self._record_voice_session_usage(
                self._elapsed_ms(session_started_at),
                status=session_status,
            )

    async def _receive_audio_chunk(self, chunk: bytes) -> None:
        if not chunk:
            return
        if self._active_turn_task is not None and not self._active_turn_task.done():
            if self._assistant_audio_started:
                LOGGER.info(
                    "voice_barge_in_audio_accepted session_id=%s conversation_id=%s",
                    self._session_id,
                    self.conversation_id,
                )
                await self._interrupt_active_turn(reason="barge_in_audio")
            else:
                LOGGER.info(
                    "voice_trailing_audio_ignored session_id=%s conversation_id=%s "
                    "audio_bytes=%s audio_chunks=%s",
                    self._session_id,
                    self.conversation_id,
                    len(chunk),
                    self._audio_chunks_received,
                )
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
            self.input_mime_type = payload.get("input_mime_type") or self.input_mime_type
            self.client = str(payload.get("client") or self.client or "")
            locale_value = payload.get("locale")
            if isinstance(locale_value, str) and locale_value.strip():
                self.locale = locale_value.strip()
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
            await self._prewarm_voice_services()
            return True

        if event == "utterance.end":
            if self._active_turn_task is not None and not self._active_turn_task.done():
                await self._send_error(
                    "Rex is still answering the previous voice turn.",
                    status_code=409,
                    code="turn_in_progress",
                )
                return True
            financial_context = payload.get("financial_context")
            if isinstance(financial_context, dict):
                self.financial_context = financial_context
            else:
                self.financial_context = None
            write_confirmation = payload.get("write_confirmation")
            if isinstance(write_confirmation, dict):
                self.write_confirmation = write_confirmation
            else:
                self.write_confirmation = None
            await self._cancel_live_endpoint_check()
            if self._live_transcription is not None:
                self._active_turn_task = asyncio.create_task(
                    self._process_live_utterance()
                )
            else:
                self._active_turn_task = asyncio.create_task(self._process_utterance())
            return True

        if event == "user.interrupt":
            await self._interrupt_active_turn(reason="user_interrupt")
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

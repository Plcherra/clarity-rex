import asyncio
import contextlib
import time
from typing import Any

from app.services.locale_utils import locale_to_stt_code


class VoiceStreamLiveTranscriptionMixin:
    def _supports_live_transcription(self) -> bool:
        return hasattr(self.deepgram_streaming_service, "open_live_transcription")

    async def _ensure_live_transcription(self) -> Any:
        if self._live_transcription is not None:
            return self._live_transcription
        self._live_transcription = (
            await self.deepgram_streaming_service.open_live_transcription(
                content_type=self.input_mime_type,
                sample_rate=self.sample_rate,
                on_transcript=self._handle_live_transcript_event,
                language=locale_to_stt_code(getattr(self, "locale", None)),
            )
        )
        return self._live_transcription

    async def _handle_live_transcript_event(self, event: dict[str, Any]) -> None:
        await self._send_transcript_event(event)
        transcript = str(event.get("transcript") or "").strip()
        if transcript and not self._requires_explicit_utterance_end():
            self._schedule_live_endpoint_check()
        if (
            event.get("event") == "transcript.final"
            and event.get("speech_final")
            and not self._requires_explicit_utterance_end()
            and (
                self._active_turn_task is None
                or self._active_turn_task.done()
            )
        ):
            self._active_turn_task = asyncio.create_task(
                self._process_live_utterance()
            )

    async def _close_live_transcription(self) -> None:
        await self._cancel_live_endpoint_check()
        live_transcription = self._live_transcription
        self._live_transcription = None
        if live_transcription is not None:
            await live_transcription.close()

    def _schedule_live_endpoint_check(self) -> None:
        self._last_live_transcript_at = time.perf_counter()
        task = self._live_endpoint_task
        if task is not None and not task.done():
            task.cancel()
        self._live_endpoint_task = asyncio.create_task(
            self._process_live_utterance_after_transcript_idle(
                self._last_live_transcript_at
            )
        )

    async def _process_live_utterance_after_transcript_idle(
        self,
        transcript_timestamp: float,
    ) -> None:
        if self._requires_explicit_utterance_end():
            return
        settings = getattr(self.deepgram_streaming_service, "settings", None)
        endpointing_ms = getattr(settings, "deepgram_endpointing_ms", 2600)
        idle_ms = getattr(
            settings,
            "deepgram_live_transcript_idle_ms",
            endpointing_ms + 200,
        )
        await asyncio.sleep(max(endpointing_ms + 200, idle_ms) / 1000)
        if self._last_live_transcript_at != transcript_timestamp:
            return
        if self._live_transcription is None:
            return
        if self._active_turn_task is not None and not self._active_turn_task.done():
            return
        self._active_turn_task = asyncio.create_task(self._process_live_utterance())

    def _requires_explicit_utterance_end(self) -> bool:
        return self.client in {"flutter_streaming", "ios_native"}

    async def _cancel_live_endpoint_check(self) -> None:
        task = self._live_endpoint_task
        if task is None or task.done():
            self._live_endpoint_task = None
            return
        if task is asyncio.current_task():
            self._live_endpoint_task = None
            return
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task
        self._live_endpoint_task = None

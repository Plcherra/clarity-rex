"""Live (Deepgram streaming) session behavior: when a turn starts and when it does not."""

from __future__ import annotations

import asyncio

import pytest

import app.services.voice_stream_session as voice_stream_session_module
from app.services.voice_stream_session import VoiceStreamSession
from voice_stream_fakes import (
    FakeChatService,
    FakeDeepgramStreamingService,
    FakeGoogleTTSService,
    FakeLiveDeepgramStreamingService,
    FakeLiveTranscription,
    FakeWebSocket,
)


def _live_session(websocket, chat, tts=None) -> VoiceStreamSession:
    return VoiceStreamSession(
        websocket=websocket,
        deepgram_streaming_service=FakeLiveDeepgramStreamingService(),
        chat_service=chat,
        google_tts_service=tts or FakeGoogleTTSService(),
    )


@pytest.mark.asyncio
async def test_voice_stream_live_transcript_idle_starts_turn(monkeypatch):
    async def instant_sleep(_delay):
        return None

    monkeypatch.setattr(voice_stream_session_module.asyncio, "sleep", instant_sleep)
    websocket = FakeWebSocket()
    chat = FakeChatService()
    session = _live_session(websocket, chat)
    session.conversation_id = "conversation-existing"
    session._live_transcription = FakeLiveTranscription()
    transcript_timestamp = 10.0
    session._last_live_transcript_at = transcript_timestamp

    await session._process_live_utterance_after_transcript_idle(
        transcript_timestamp,
    )
    assert session._active_turn_task is not None
    await session._active_turn_task

    assert chat.stream_calls[0]["message"] == "Hey Rex"
    assert any(event["event"] == "assistant.done" for event in websocket.events)


@pytest.mark.asyncio
async def test_voice_stream_live_blank_transcription_recovers_as_empty_audio():
    class BlankLiveTranscription:
        async def finish(self):
            return {
                "transcript": "   ",
                "confidence": 0.2,
                "duration_seconds": 0.1,
                "metadata": {"transport": "websocket-live"},
            }

    websocket = FakeWebSocket()
    chat = FakeChatService()
    tts = FakeGoogleTTSService()
    session = _live_session(websocket, chat, tts)
    session._live_transcription = BlankLiveTranscription()

    await session._process_live_utterance()

    assert websocket.events[-1]["event"] == "error"
    assert websocket.events[-1]["code"] == "empty_audio"
    assert chat.stream_calls == []
    assert tts.calls == []


@pytest.mark.asyncio
async def test_voice_stream_live_blank_finish_uses_client_transcript_fallback():
    class BlankLiveTranscription:
        async def finish(self):
            return {
                "transcript": "   ",
                "confidence": 0.2,
                "duration_seconds": 0.1,
                "metadata": {"transport": "websocket-live"},
            }

    websocket = FakeWebSocket()
    chat = FakeChatService()
    tts = FakeGoogleTTSService()
    session = _live_session(websocket, chat, tts)
    session.conversation_id = "conversation-existing"
    session._live_transcription = BlankLiveTranscription()
    session.client_transcript = "Buy more coffee"

    await session._process_live_utterance()

    assert chat.stream_calls[0]["message"] == "Buy more coffee"
    assert any(event["event"] == "assistant.done" for event in websocket.events)
    assert not any(
        event.get("code") == "empty_audio" for event in websocket.events
    )


@pytest.mark.asyncio
async def test_voice_stream_live_none_uses_streamed_transcript_fallback():
    websocket = FakeWebSocket()
    chat = FakeChatService()
    tts = FakeGoogleTTSService()
    session = _live_session(websocket, chat, tts)
    session.conversation_id = "conversation-existing"
    session._live_transcription = None
    session._last_streamed_transcript = "Hello from partials"

    await session._process_live_utterance()

    assert chat.stream_calls[0]["message"] == "Hello from partials"
    assert any(event["event"] == "assistant.done" for event in websocket.events)


@pytest.mark.asyncio
async def test_voice_stream_live_transcript_idle_uses_timing_contract(monkeypatch):
    delays = []

    async def capture_sleep(delay):
        delays.append(delay)

    monkeypatch.setattr(voice_stream_session_module.asyncio, "sleep", capture_sleep)
    session = _live_session(FakeWebSocket(), FakeChatService())
    session._live_transcription = FakeLiveTranscription()
    session._last_live_transcript_at = 10.0

    await session._process_live_utterance_after_transcript_idle(10.0)

    assert delays == [4.2]


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "client_name",
    ["ios_native", "flutter_streaming", "flutter_streaming_web"],
)
async def test_voice_stream_client_waits_for_explicit_utterance_end(
    monkeypatch,
    client_name,
):
    async def instant_sleep(_delay):
        return None

    monkeypatch.setattr(voice_stream_session_module.asyncio, "sleep", instant_sleep)
    websocket = FakeWebSocket()
    chat = FakeChatService()
    session = _live_session(websocket, chat)
    session.client = client_name
    session.conversation_id = "conversation-existing"
    session._live_transcription = FakeLiveTranscription()

    await session._handle_live_transcript_event(
        {
            "event": "transcript.final",
            "transcript": "what if we change the whole app actually",
            "confidence": 0.9,
            "speech_final": True,
            "metadata": {"vendor": "deepgram"},
        }
    )
    assert session._active_turn_task is None

    session._last_live_transcript_at = 10.0
    await session._process_live_utterance_after_transcript_idle(10.0)
    assert session._active_turn_task is None
    assert chat.stream_calls == []

    await session._receive_text_event('{"event":"utterance.end"}')
    assert session._active_turn_task is not None
    await session._active_turn_task

    assert chat.stream_calls[0]["message"] == "Hey Rex"
    assert any(event["event"] == "assistant.done" for event in websocket.events)


@pytest.mark.asyncio
async def test_voice_stream_ignores_trailing_audio_before_assistant_audio():
    websocket = FakeWebSocket()
    session = VoiceStreamSession(
        websocket=websocket,
        deepgram_streaming_service=FakeDeepgramStreamingService(),
        chat_service=FakeChatService(),
        google_tts_service=FakeGoogleTTSService(),
    )
    session._active_turn_task = asyncio.create_task(asyncio.sleep(2))
    session._assistant_audio_started = False

    await session._receive_audio_chunk(b"late-capture-frame")

    assert websocket.events == []
    assert session._audio_chunks == []
    assert session._audio_bytes == 0
    assert session._audio_chunks_received == 0

    await session._cancel_active_turn()

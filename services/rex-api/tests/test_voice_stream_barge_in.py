"""Barge-in: new speech cancels the turn being spoken and starts the next one."""

from __future__ import annotations

import asyncio

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.voice_stream_session import VoiceStreamSession
from voice_stream_fakes import (
    FakeDeepgramStreamingService,
    FakeGoogleTTSService,
    FakeWebSocket,
    override_services,
    receive_until,
)


@pytest.fixture
def client():
    app.dependency_overrides.clear()
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


class SequencedDeepgramStreamingService:
    def __init__(self, transcripts):
        self.transcripts = transcripts
        self.calls = []

    async def transcribe_audio_stream(
        self,
        audio_chunks,
        content_type: str,
        sample_rate: int = 16000,
        on_transcript=None,
    ):
        chunks = []
        async for chunk in audio_chunks:
            chunks.append(chunk)
        self.calls.append(
            {
                "audio_chunks": chunks,
                "content_type": content_type,
                "sample_rate": sample_rate,
            }
        )
        transcript = self.transcripts[len(self.calls) - 1]
        if on_transcript is not None:
            await on_transcript(
                {
                    "event": "transcript.partial",
                    "transcript": transcript["partial"],
                    "confidence": 0.7,
                    "metadata": {"vendor": "deepgram"},
                }
            )
        return {
            "transcript": transcript["transcript"],
            "confidence": 0.94,
            "duration_seconds": 0.8,
            "metadata": {"request_id": f"stream-request-{len(self.calls)}"},
        }


class PausingFirstTurnChatService:
    def __init__(self):
        self.stream_calls = []
        self.metadata_calls = []

    async def stream_message(
        self,
        message,
        conversation_id=None,
        file=None,
        response_instructions=None,
        max_response_tokens=None,
        financial_context=None,
        channel=None,
        user_requested_deep_thinking=False,
        include_turn_trace=False,
        locale=None,
        write_confirmation=None,
        user_enabled_proactive_insights=False,
    ):
        self.stream_calls.append(
            {
                "message": message,
                "conversation_id": conversation_id,
                "file": file,
                "response_instructions": response_instructions,
                "max_response_tokens": max_response_tokens,
                "financial_context": financial_context,
                "channel": channel,
                "include_turn_trace": include_turn_trace,
            }
        )
        yield {"event": "conversation", "conversation_id": "conversation-barge-in"}
        if include_turn_trace:
            yield {
                "event": "turn.trace",
                "intent": "casual",
                "channel": "voice",
                "loaded_context": {},
            }
        if len(self.stream_calls) == 1:
            yield {
                "event": "token",
                "token": "Old response is still being spoken now while Rex continues.",
            }
            await asyncio.sleep(2)
            return

        yield {"event": "token", "token": "Fresh "}
        yield {"event": "token", "token": "response."}
        yield {
            "event": "done",
            "conversation_id": "conversation-barge-in",
            "response": "Fresh response.",
            "messages": [
                {
                    "id": "user-message-2",
                    "conversation_id": "conversation-barge-in",
                    "role": "user",
                    "content": message,
                    "timestamp": "2026-05-17T00:00:02Z",
                },
                {
                    "id": "assistant-message-2",
                    "conversation_id": "conversation-barge-in",
                    "role": "assistant",
                    "content": "Fresh response.",
                    "timestamp": "2026-05-17T00:00:03Z",
                },
            ],
        }

    async def save_voice_turn_metadata(self, **kwargs):
        self.metadata_calls.append(kwargs)
        return {"id": "voice-turn-barge-in", **kwargs}


class LongTokenChatService:
    def __init__(self):
        self.stream_calls = []
        self.metadata_calls = []

    async def stream_message(
        self,
        message,
        conversation_id=None,
        file=None,
        response_instructions=None,
        max_response_tokens=None,
        financial_context=None,
        channel=None,
        user_requested_deep_thinking=False,
        include_turn_trace=False,
        locale=None,
        write_confirmation=None,
        user_enabled_proactive_insights=False,
    ):
        self.stream_calls.append(
            {
                "message": message,
                "conversation_id": conversation_id,
                "file": file,
                "response_instructions": response_instructions,
                "max_response_tokens": max_response_tokens,
                "financial_context": financial_context,
                "channel": channel,
                "include_turn_trace": include_turn_trace,
            }
        )
        yield {"event": "conversation", "conversation_id": "conversation-interrupt"}
        if include_turn_trace:
            yield {
                "event": "turn.trace",
                "intent": "casual",
                "channel": "voice",
                "loaded_context": {},
            }
        yield {
            "event": "token",
            "token": "This response will be interrupted before audio can be sent.",
        }
        yield {
            "event": "done",
            "conversation_id": "conversation-interrupt",
            "response": "This response will be interrupted before audio can be sent.",
            "messages": [],
        }

    async def save_voice_turn_metadata(self, **kwargs):
        self.metadata_calls.append(kwargs)
        return {"id": "voice-turn-interrupt", **kwargs}


class SlowGoogleTTSService:
    def __init__(self):
        self.calls = []
        self.started = asyncio.Event()

    async def synthesize_speech(self, text, *, language_code=None):
        self.calls.append(text)
        self.started.set()
        await asyncio.sleep(2)
        return {
            "audio_content_type": "audio/mpeg",
            "audio_base64": "bXAzLWJ5dGVz",
            "audio_encoding": "MP3",
            "voice_name": "en-US-Neural2-J",
            "language_code": "en-US",
            "metadata": {"vendor": "google_tts"},
        }


@pytest.mark.asyncio
async def test_voice_stream_interrupt_cancels_pending_tts_audio():
    websocket = FakeWebSocket()
    tts = SlowGoogleTTSService()
    session = VoiceStreamSession(
        websocket=websocket,
        deepgram_streaming_service=FakeDeepgramStreamingService(),
        chat_service=LongTokenChatService(),
        google_tts_service=tts,
    )

    await session._receive_audio_chunk(b"pcm-frame")
    await session._receive_text_event('{"event":"utterance.end"}')
    await asyncio.wait_for(tts.started.wait(), timeout=1)

    await session._receive_text_event('{"event":"user.interrupt"}')

    assert [event["event"] for event in websocket.events].count(
        "assistant.audio_chunk"
    ) == 0
    assert any(event["event"] == "session.interrupted" for event in websocket.events)
    assert session._active_tts_tasks == set()
    assert session._active_audio_flush_tasks == set()


def test_voice_stream_audio_barge_in_cancels_active_turn_and_starts_next(client):
    deepgram = SequencedDeepgramStreamingService(
        [
            {"transcript": "First turn", "partial": "First"},
            {"transcript": "Second turn", "partial": "Second"},
        ]
    )
    chat = PausingFirstTurnChatService()
    tts = FakeGoogleTTSService()
    override_services(
        deepgram_streaming_service=deepgram,
        chat_service=chat,
        google_tts_service=tts,
    )

    with client.websocket_connect("/voice/stream") as websocket:
        websocket.send_json({"event": "session.start"})
        assert websocket.receive_json()["event"] == "session.started"

        websocket.send_bytes(b"first-audio")
        assert websocket.receive_json()["event"] == "audio.received"
        websocket.send_json({"event": "utterance.end"})
        token = receive_until(websocket, "assistant.token")
        assert token["token"] == (
            "Old response is still being spoken now while Rex continues."
        )
        old_audio = receive_until(websocket, "assistant.audio_chunk")
        assert old_audio["text"] == (
            "Old response is still being spoken now while Rex continues."
        )

        websocket.send_bytes(b"barge-in-audio")
        interrupted = receive_until(websocket, "session.interrupted")
        assert interrupted["reason"] == "barge_in_audio"
        received = receive_until(websocket, "audio.received")
        assert received["chunk_count"] == 1

        websocket.send_json({"event": "utterance.end"})
        final = receive_until(websocket, "transcript.final")
        assert final["transcript"] == "Second turn"
        done = receive_until(websocket, "assistant.done")
        assert done["response_text"] == "Fresh response."

    assert [call["message"] for call in chat.stream_calls] == [
        "First turn",
        "Second turn",
    ]
    assert deepgram.calls == [
        {
            "audio_chunks": [b"first-audio"],
            "content_type": "audio/linear16",
            "sample_rate": 16000,
        },
        {
            "audio_chunks": [b"barge-in-audio"],
            "content_type": "audio/linear16",
            "sample_rate": 16000,
        },
    ]
    assert len(chat.metadata_calls) == 1
    assert chat.metadata_calls[0]["user_message_id"] == "user-message-2"
    assert tts.calls == [
        "Old response is still being spoken now while Rex continues.",
        "Fresh response.",
    ]

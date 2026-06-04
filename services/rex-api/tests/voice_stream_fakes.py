from collections.abc import AsyncIterator
import asyncio
from types import SimpleNamespace

from app.dependencies import (
    get_chat_service,
    get_deepgram_streaming_service,
    get_google_tts_service,
)
from app.main import app


class FakeDeepgramStreamingService:
    def __init__(
        self,
        error=None,
        transcript="Hey Rex",
        partial_transcript="Hey",
        confidence=0.96,
    ):
        self.error = error
        self.transcript = transcript
        self.partial_transcript = partial_transcript
        self.confidence = confidence
        self.calls = []

    async def transcribe_audio_stream(
        self,
        audio_chunks: AsyncIterator[bytes],
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
        if self.error is not None:
            raise self.error
        if on_transcript is not None:
            await on_transcript(
                {
                    "event": "transcript.partial",
                    "transcript": self.partial_transcript,
                    "confidence": 0.7,
                    "metadata": {"vendor": "deepgram"},
                }
            )
        return {
            "transcript": self.transcript,
            "confidence": self.confidence,
            "duration_seconds": 1.4,
            "metadata": {"request_id": "stream-request-1"},
        }


class SlowDeepgramStreamingService(FakeDeepgramStreamingService):
    async def transcribe_audio_stream(
        self,
        audio_chunks: AsyncIterator[bytes],
        content_type: str,
        sample_rate: int = 16000,
        on_transcript=None,
    ):
        async for _ in audio_chunks:
            pass
        await asyncio.sleep(30)
        return await super().transcribe_audio_stream(
            self._empty_chunks(),
            content_type=content_type,
            sample_rate=sample_rate,
            on_transcript=on_transcript,
        )

    async def _empty_chunks(self):
        if False:
            yield b""


class FakeChatService:
    def __init__(self, error=None):
        self.error = error
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
            }
        )
        if self.error is not None:
            raise self.error
        resolved_conversation_id = conversation_id or "conversation-stream"
        yield {"event": "conversation", "conversation_id": resolved_conversation_id}
        yield {"event": "token", "token": "Rex "}
        yield {"event": "token", "token": "streaming "}
        yield {"event": "token", "token": "response."}
        yield {
            "event": "done",
            "conversation_id": resolved_conversation_id,
            "response": "Rex streaming response.",
            "messages": [
                {
                    "id": "user-message-1",
                    "conversation_id": resolved_conversation_id,
                    "role": "user",
                    "content": message,
                    "timestamp": "2026-05-17T00:00:00Z",
                },
                {
                    "id": "assistant-message-1",
                    "conversation_id": resolved_conversation_id,
                    "role": "assistant",
                    "content": "Rex streaming response.",
                    "timestamp": "2026-05-17T00:00:01Z",
                },
            ],
        }

    async def save_voice_turn_metadata(self, **kwargs):
        self.metadata_calls.append(kwargs)
        return {"id": "voice-turn-stream", **kwargs}


class FakeGoogleTTSService:
    def __init__(self, error=None):
        self.error = error
        self.calls = []

    async def synthesize_speech(self, text):
        self.calls.append(text)
        if self.error is not None:
            raise self.error
        return {
            "audio_content_type": "audio/mpeg",
            "audio_base64": "bXAzLWJ5dGVz",
            "audio_encoding": "MP3",
            "voice_name": "en-US-Neural2-J",
            "language_code": "en-US",
            "metadata": {"vendor": "google_tts"},
        }


class FakeWebSocket:
    def __init__(self):
        self.events = []

    async def send_json(self, payload):
        self.events.append(payload)


class FakeLiveTranscription:
    def __init__(self):
        self.closed = False

    async def finish(self):
        return {
            "transcript": "Hey Rex",
            "confidence": 0.91,
            "duration_seconds": 1.2,
            "metadata": {"transport": "websocket-live"},
        }

    async def close(self):
        self.closed = True


class FakeLiveDeepgramStreamingService:
    settings = SimpleNamespace(
        deepgram_endpointing_ms=900,
        deepgram_live_transcript_idle_ms=1100,
    )


def override_services(
    deepgram_streaming_service=None,
    chat_service=None,
    google_tts_service=None,
):
    app.dependency_overrides[get_deepgram_streaming_service] = (
        lambda: deepgram_streaming_service or FakeDeepgramStreamingService()
    )
    app.dependency_overrides[get_chat_service] = (
        lambda: chat_service or FakeChatService()
    )
    app.dependency_overrides[get_google_tts_service] = (
        lambda: google_tts_service or FakeGoogleTTSService()
    )


def receive_until(websocket, event_name):
    while True:
        event = websocket.receive_json()
        if event["event"] == event_name:
            return event

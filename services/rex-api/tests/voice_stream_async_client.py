"""Async WebSocket test helpers using httpx-ws ASGI transport."""

from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager

import httpx
import pytest
from httpx_ws import aconnect_ws
from httpx_ws.transport import ASGIWebSocketTransport

from app.main import app
from voice_stream_fakes import (
    FakeDeepgramStreamingService,
    FakeGoogleTTSService,
    override_services,
)


@asynccontextmanager
async def async_voice_client():
    app.dependency_overrides.clear()
    transport = ASGIWebSocketTransport(app=app)
    async with httpx.AsyncClient(
        transport=transport,
        base_url="http://testserver",
    ) as client:
        try:
            yield client
        finally:
            app.dependency_overrides.clear()


async def async_receive_until(
    websocket,
    event_name: str,
    *,
    timeout: float = 15.0,
    max_messages: int = 200,
):
    seen: list[dict] = []
    for _ in range(max_messages):
        try:
            event = await asyncio.wait_for(websocket.receive_json(), timeout=timeout)
        except asyncio.TimeoutError:
            pytest.fail(
                f"Timed out after {timeout}s waiting for {event_name!r}. Saw: {seen}"
            )
        if event.get("event") == "error" and event_name != "error":
            pytest.fail(
                f"Unexpected error while waiting for {event_name!r}: {event}. "
                f"Previously saw: {seen}"
            )
        if event["event"] == event_name:
            return event
        seen.append(event)
    pytest.fail(
        f"Exceeded max_messages={max_messages} waiting for {event_name!r}. Saw: {seen}"
    )


async def async_voice_websocket_turn(
    client,
    chat,
    transcript,
    conversation_id=None,
    *,
    deepgram=None,
    tts=None,
    write_confirmation=None,
    partial_transcript=None,
    timeout=15.0,
):
    deepgram = deepgram or FakeDeepgramStreamingService(
        transcript=transcript,
        partial_transcript=partial_transcript,
    )
    tts = tts or FakeGoogleTTSService()
    override_services(
        deepgram_streaming_service=deepgram,
        chat_service=chat,
        google_tts_service=tts,
    )

    start_payload = {"event": "session.start"}
    if conversation_id is not None:
        start_payload["conversation_id"] = conversation_id

    utterance_end_payload: dict = {"event": "utterance.end"}
    if write_confirmation is not None:
        utterance_end_payload["write_confirmation"] = write_confirmation

    async with aconnect_ws("http://testserver/voice/stream", client) as websocket:
        await websocket.send_json(start_payload)
        await websocket.receive_json()
        await websocket.send_bytes(b"pcm-frame")
        await websocket.receive_json()
        await websocket.send_json(utterance_end_payload)
        done = await async_receive_until(
            websocket,
            "assistant.done",
            timeout=timeout,
        )
        return done, tts


async def async_confirm_voice_proposal(client, chat, proposed_turn, *, transcript="Yes"):
    proposals = (proposed_turn.get("memory_changes") or {}).get("write_proposals") or []
    if not proposals:
        raise AssertionError("Expected a pending write proposal to confirm.")
    proposal_id = proposals[0]["id"]
    done, _ = await async_voice_websocket_turn(
        client,
        chat,
        transcript,
        proposed_turn["conversation_id"],
        write_confirmation={"proposal_id": proposal_id},
    )
    return done

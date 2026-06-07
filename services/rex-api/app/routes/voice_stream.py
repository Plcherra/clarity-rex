from fastapi import APIRouter, Depends, WebSocket
from starlette.websockets import WebSocketState

from app.auth.supabase_auth import authenticate_websocket
from app.dependencies import (
    get_chat_service,
    get_deepgram_streaming_service,
    get_google_tts_service,
    get_usage_tracking_service,
)
from app.services.chat_service import ChatService
from app.services.deepgram_streaming_service import DeepgramStreamingService
from app.services.google_tts_service import GoogleTTSService
from app.services.usage_tracking_service import UsageTrackingService
from app.services.voice_stream_session import VoiceStreamSession


router = APIRouter(tags=["voice"])


@router.websocket("/voice/stream")
async def stream_voice(
    websocket: WebSocket,
    deepgram_streaming_service: DeepgramStreamingService = Depends(
        get_deepgram_streaming_service
    ),
    chat_service: ChatService = Depends(get_chat_service),
    google_tts_service: GoogleTTSService = Depends(get_google_tts_service),
    usage_tracking_service: UsageTrackingService = Depends(get_usage_tracking_service),
) -> None:
    try:
        current_user = await authenticate_websocket(websocket)
    except Exception:
        await websocket.accept()
        if websocket.client_state == WebSocketState.CONNECTED:
            await websocket.close(code=1008)
        return

    session = VoiceStreamSession(
        websocket=websocket,
        deepgram_streaming_service=deepgram_streaming_service,
        chat_service=chat_service,
        google_tts_service=google_tts_service,
        usage_tracking_service=usage_tracking_service,
        user_id=current_user.id,
    )
    await session.run()

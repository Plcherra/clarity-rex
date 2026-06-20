import json
import time
from typing import Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.dependencies import (
    get_chat_service,
    get_deepgram_service,
    get_google_tts_service,
    get_usage_tracking_service,
)
from app.models.voice import (
    VoiceSynthesisRequest,
    VoiceSynthesisResponse,
    VoiceTranscriptionResponse,
    VoiceTurnResponse,
)
from app.services.ai_service import AIServiceError
from app.services.chat_service import ChatService, ConversationNotFoundError
from app.services.deepgram_service import DeepgramService, DeepgramServiceError
from app.services.google_tts_service import (
    GoogleTTSService,
    GoogleTTSServiceError,
    estimate_tts_duration_ms,
)
from app.services.memory_service import MemoryServiceError
from app.services.rex_channel import RexBrainChannel
from app.services.usage_tracking_service import UsageTrackingService
from app.services.voice_stream_session import (
    VOICE_RESPONSE_INSTRUCTIONS,
    voice_response_max_tokens,
)


router = APIRouter(prefix="/voice", tags=["voice"])

MAX_AUDIO_UPLOAD_BYTES = 10 * 1024 * 1024
SUPPORTED_AUDIO_TYPES = {
    "audio/aac",
    "audio/mp4",
    "audio/m4a",
    "audio/x-m4a",
    "audio/mpeg",
    "audio/mp3",
    "audio/wav",
    "audio/x-wav",
    "audio/webm",
    "application/octet-stream",
}
VOICE_TURN_RESPONSE_INSTRUCTIONS = VOICE_RESPONSE_INSTRUCTIONS


@router.post("/transcribe", response_model=VoiceTranscriptionResponse)
async def transcribe_voice(
    audio: UploadFile = File(...),
    input_mime_type: Optional[str] = Form(None),
    current_user: AuthenticatedUser = Depends(get_current_user),
    deepgram_service: DeepgramService = Depends(get_deepgram_service),
    usage_tracking_service: UsageTrackingService = Depends(get_usage_tracking_service),
) -> VoiceTranscriptionResponse:
    audio_bytes, content_type = await _read_audio_upload(audio, input_mime_type)

    started_at = time.perf_counter()
    try:
        transcription = await deepgram_service.transcribe_audio(
            audio_bytes=audio_bytes,
            content_type=content_type,
            filename=audio.filename,
        )
    except DeepgramServiceError as error:
        await usage_tracking_service.record_stt_turn(
            user_id=current_user.id,
            model=_deepgram_model(deepgram_service),
            latency_ms=_elapsed_ms(started_at),
            status="failure",
            error_class=error.__class__.__name__,
        )
        raise HTTPException(status_code=error.status_code, detail=error.detail) from error
    await usage_tracking_service.record_stt_turn(
        user_id=current_user.id,
        duration_ms=_duration_seconds_to_ms(transcription.get("duration_seconds")),
        latency_ms=_elapsed_ms(started_at),
        model=_deepgram_model(deepgram_service),
    )

    return VoiceTranscriptionResponse(**transcription)


@router.post("/turn", response_model=VoiceTurnResponse)
async def voice_turn(
    audio: UploadFile = File(...),
    conversation_id: Optional[str] = Form(None),
    input_mime_type: Optional[str] = Form(None),
    financial_context: Optional[str] = Form(None),
    current_user: AuthenticatedUser = Depends(get_current_user),
    deepgram_service: DeepgramService = Depends(get_deepgram_service),
    chat_service: ChatService = Depends(get_chat_service),
    google_tts_service: GoogleTTSService = Depends(get_google_tts_service),
    usage_tracking_service: UsageTrackingService = Depends(get_usage_tracking_service),
) -> VoiceTurnResponse:
    audio_bytes, content_type = await _read_audio_upload(audio, input_mime_type)

    turn_started_at = time.perf_counter()
    stt_started_at = turn_started_at
    transcription = None
    try:
        transcription = await deepgram_service.transcribe_audio(
            audio_bytes=audio_bytes,
            content_type=content_type,
            filename=audio.filename,
        )
        await usage_tracking_service.record_stt_turn(
            user_id=current_user.id,
            duration_ms=_duration_seconds_to_ms(transcription.get("duration_seconds")),
            latency_ms=_elapsed_ms(stt_started_at),
            model=_deepgram_model(deepgram_service),
        )
        chat_result = await chat_service.send_message(
            message=transcription["transcript"],
            conversation_id=conversation_id,
            financial_context=_json_dict(financial_context),
            response_instructions=VOICE_TURN_RESPONSE_INSTRUCTIONS,
            max_response_tokens=voice_response_max_tokens(transcription["transcript"]),
            channel=RexBrainChannel.VOICE,
        )
        tts_started_at = time.perf_counter()
        synthesis = await google_tts_service.synthesize_speech(chat_result["response"])
        await usage_tracking_service.record_tts_turn(
            user_id=current_user.id,
            duration_ms=estimate_tts_duration_ms(chat_result["response"]),
            latency_ms=_elapsed_ms(tts_started_at),
            model=synthesis.get("voice_name") or _google_tts_model(google_tts_service),
        )
    except DeepgramServiceError as error:
        await usage_tracking_service.record_stt_turn(
            user_id=current_user.id,
            latency_ms=_elapsed_ms(stt_started_at),
            model=_deepgram_model(deepgram_service),
            status="failure",
            error_class=error.__class__.__name__,
        )
        await usage_tracking_service.record_voice_session(
            user_id=current_user.id,
            duration_ms=_voice_session_duration_ms(turn_started_at, transcription),
            status="failure",
        )
        raise HTTPException(status_code=error.status_code, detail=error.detail) from error
    except ConversationNotFoundError as error:
        await usage_tracking_service.record_voice_session(
            user_id=current_user.id,
            duration_ms=_voice_session_duration_ms(turn_started_at, transcription),
            status="failure",
        )
        raise HTTPException(status_code=404, detail="Conversation not found.") from error
    except AIServiceError as error:
        await usage_tracking_service.record_voice_session(
            user_id=current_user.id,
            duration_ms=_voice_session_duration_ms(turn_started_at, transcription),
            status="failure",
        )
        raise HTTPException(status_code=error.status_code, detail=error.detail) from error
    except MemoryServiceError as error:
        await usage_tracking_service.record_voice_session(
            user_id=current_user.id,
            duration_ms=_voice_session_duration_ms(turn_started_at, transcription),
            status="failure",
        )
        raise HTTPException(status_code=error.status_code, detail=error.detail) from error
    except GoogleTTSServiceError as error:
        await usage_tracking_service.record_tts_turn(
            user_id=current_user.id,
            model=_google_tts_model(google_tts_service),
            status="failure",
            error_class=error.__class__.__name__,
        )
        await usage_tracking_service.record_voice_session(
            user_id=current_user.id,
            duration_ms=_voice_session_duration_ms(turn_started_at, transcription),
            status="failure",
        )
        raise HTTPException(status_code=error.status_code, detail=error.detail) from error
    await usage_tracking_service.record_voice_session(
        user_id=current_user.id,
        duration_ms=_voice_session_duration_ms(turn_started_at, transcription),
    )

    user_message = chat_result.get("user_message") or {}
    assistant_message = chat_result.get("assistant_message") or {}
    voice_metadata = {
        "stt": transcription.get("metadata") or {},
        "tts": synthesis.get("metadata") or {},
    }
    try:
        metadata_record = await chat_service.save_voice_turn_metadata(
            conversation_id=chat_result["conversation_id"],
            user_message_id=user_message.get("id"),
            assistant_message_id=assistant_message.get("id"),
            transcript_confidence=transcription.get("confidence"),
            audio_duration_seconds=transcription.get("duration_seconds"),
            input_mime_type=content_type,
            output_audio_encoding=synthesis.get("audio_encoding"),
            metadata={
                "stt": transcription.get("metadata") or {},
                "tts": synthesis.get("metadata") or {},
            },
        )
    except Exception:
        metadata_record = None

    if metadata_record is not None:
        voice_metadata["record"] = {
            key: value
            for key, value in metadata_record.items()
            if key != "metadata"
        }

    return VoiceTurnResponse(
        conversation_id=chat_result["conversation_id"],
        transcript=transcription["transcript"],
        transcript_confidence=transcription.get("confidence"),
        response_text=chat_result["response"],
        audio_content_type=synthesis["audio_content_type"],
        audio_base64=synthesis["audio_base64"],
        audio_encoding=synthesis["audio_encoding"],
        voice_name=synthesis["voice_name"],
        language_code=synthesis["language_code"],
        messages=chat_result.get("messages") or [],
        voice_metadata=voice_metadata,
    )


@router.post("/synthesize", response_model=VoiceSynthesisResponse)
async def synthesize_voice(
    request: VoiceSynthesisRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    google_tts_service: GoogleTTSService = Depends(get_google_tts_service),
    usage_tracking_service: UsageTrackingService = Depends(get_usage_tracking_service),
) -> VoiceSynthesisResponse:
    started_at = time.perf_counter()
    try:
        synthesis = await google_tts_service.synthesize_speech(request.text)
    except GoogleTTSServiceError as error:
        await usage_tracking_service.record_tts_turn(
            user_id=current_user.id,
            latency_ms=_elapsed_ms(started_at),
            model=_google_tts_model(google_tts_service),
            status="failure",
            error_class=error.__class__.__name__,
        )
        raise HTTPException(status_code=error.status_code, detail=error.detail) from error
    await usage_tracking_service.record_tts_turn(
        user_id=current_user.id,
        duration_ms=estimate_tts_duration_ms(request.text),
        latency_ms=_elapsed_ms(started_at),
        model=synthesis.get("voice_name") or _google_tts_model(google_tts_service),
    )

    return VoiceSynthesisResponse(**synthesis)


async def _read_audio_upload(
    audio: UploadFile,
    input_mime_type: Optional[str],
) -> tuple[bytes, str]:
    content_type = (input_mime_type or audio.content_type or "").strip().lower()
    if content_type not in SUPPORTED_AUDIO_TYPES:
        raise HTTPException(
            status_code=415,
            detail="Unsupported audio type. Use m4a/aac, mp3, wav, or webm audio.",
        )

    audio_bytes = await audio.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="I did not catch any audio.")
    if len(audio_bytes) > MAX_AUDIO_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Voice recording is too long.")

    return audio_bytes, content_type


def _json_dict(value: Optional[str]) -> Optional[dict]:
    if value is None or not value.strip():
        return None
    try:
        decoded = json.loads(value)
    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail="Invalid financial context.",
        ) from error
    if not isinstance(decoded, dict):
        raise HTTPException(
            status_code=422,
            detail="Financial context must be an object.",
        )
    return decoded


def _duration_seconds_to_ms(value) -> Optional[int]:
    if not isinstance(value, (int, float)):
        return None
    return max(0, round(float(value) * 1000))


def _voice_session_duration_ms(started_at: float, transcription: Optional[dict]) -> int:
    if transcription:
        duration_ms = _duration_seconds_to_ms(transcription.get("duration_seconds"))
        if duration_ms is not None:
            return duration_ms
    return _elapsed_ms(started_at)


def _elapsed_ms(started_at: float) -> int:
    return max(0, round((time.perf_counter() - started_at) * 1000))


def _deepgram_model(service: DeepgramService) -> str:
    settings = getattr(service, "settings", None)
    model = getattr(settings, "deepgram_model", None)
    return model if isinstance(model, str) and model.strip() else "unknown"


def _google_tts_model(service: GoogleTTSService) -> str:
    settings = getattr(service, "settings", None)
    model = getattr(settings, "google_tts_voice_name", None)
    return model if isinstance(model, str) and model.strip() else "unknown"

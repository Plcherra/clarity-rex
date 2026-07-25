"""Deepgram Aura TTS — Spanish (and other) speak API."""

from __future__ import annotations

import base64
from typing import Any, Optional

import httpx

from app.config import Settings, get_settings
from app.services.http_client import request_with_retries


class DeepgramTTSServiceError(Exception):
    def __init__(self, detail: str, status_code: int = 503) -> None:
        super().__init__(detail)
        self.detail = detail
        self.status_code = status_code


class DeepgramTTSService:
    """REST speak → same result shape as GoogleTTSService.synthesize_speech."""

    max_text_characters = 2000

    def __init__(self, settings: Optional[Settings] = None) -> None:
        self.settings = settings or get_settings()

    async def synthesize_speech(
        self,
        text: str,
        *,
        model: Optional[str] = None,
        language_code: Optional[str] = None,
    ) -> dict[str, Any]:
        normalized_text = text.strip()
        if not normalized_text:
            raise DeepgramTTSServiceError(
                "Text to speak cannot be empty.",
                status_code=400,
            )
        if len(normalized_text) > self.max_text_characters:
            raise DeepgramTTSServiceError(
                "Text is too long for voice playback.",
                status_code=400,
            )
        if not self.settings.deepgram_api_key:
            raise DeepgramTTSServiceError(
                "Voice playback is not configured.",
                status_code=503,
            )

        voice_model = (model or self.settings.deepgram_tts_model_es).strip()
        encoding = (self.settings.deepgram_tts_encoding or "mp3").strip().lower()

        try:
            response = await request_with_retries(
                "POST",
                self.settings.deepgram_speak_url,
                headers={
                    "Authorization": f"Token {self.settings.deepgram_api_key}",
                    "Content-Type": "application/json",
                },
                params={
                    "model": voice_model,
                    "encoding": encoding,
                },
                json={"text": normalized_text},
                timeout=self.settings.deepgram_timeout_seconds,
            )
            response.raise_for_status()
        except httpx.HTTPStatusError as error:
            raise self._http_status_error(error.response) from error
        except (httpx.RequestError, TimeoutError) as error:
            raise DeepgramTTSServiceError(
                "Cannot reach Deepgram voice playback right now.",
                status_code=503,
            ) from error

        audio_bytes = response.content
        if not audio_bytes:
            raise DeepgramTTSServiceError(
                "Deepgram returned no audio.",
                status_code=502,
            )

        return {
            "audio_content_type": self._audio_content_type(encoding),
            "audio_base64": base64.b64encode(audio_bytes).decode("ascii"),
            "audio_encoding": encoding.upper(),
            "voice_name": voice_model,
            "language_code": language_code or "es",
            "metadata": {
                "vendor": "deepgram_aura",
                "text_character_count": len(normalized_text),
                "model": voice_model,
            },
        }

    def _audio_content_type(self, encoding: str) -> str:
        if encoding == "mp3":
            return "audio/mpeg"
        if encoding in {"linear16", "wav"}:
            return "audio/wav"
        if encoding in {"ogg", "opus"}:
            return "audio/ogg"
        return "application/octet-stream"

    def _http_status_error(self, response: httpx.Response) -> DeepgramTTSServiceError:
        detail = self._error_detail(response)
        if response.status_code in {401, 403}:
            return DeepgramTTSServiceError(
                detail or "Deepgram authentication failed. Check the API key.",
                status_code=503,
            )
        if response.status_code == 400:
            return DeepgramTTSServiceError(
                detail or "Deepgram rejected the voice request.",
                status_code=400,
            )
        if response.status_code == 429:
            return DeepgramTTSServiceError(
                detail or "Deepgram is rate limiting voice playback.",
                status_code=503,
            )
        return DeepgramTTSServiceError(
            detail or "Deepgram voice playback failed.",
            status_code=503,
        )

    def _error_detail(self, response: httpx.Response) -> str:
        try:
            data = response.json()
        except ValueError:
            return response.text.strip()
        if isinstance(data, dict):
            for key in ("err_msg", "message", "error", "detail"):
                value = data.get(key)
                if isinstance(value, str) and value.strip():
                    return value.strip()
        return response.text.strip()

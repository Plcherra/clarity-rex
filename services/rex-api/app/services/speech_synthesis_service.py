"""Route TTS by locale: Spanish → Deepgram Aura, else Google."""

from __future__ import annotations

from typing import Any, Optional

from app.config import Settings, get_settings
from app.services.deepgram_tts_service import (
    DeepgramTTSService,
    DeepgramTTSServiceError,
)
from app.services.google_tts_service import GoogleTTSService, GoogleTTSServiceError
from app.services.locale_utils import locale_to_tts_code, normalize_locale


class SpeechSynthesisService:
    """Drop-in for GoogleTTSService with per-language provider routing."""

    def __init__(
        self,
        settings: Optional[Settings] = None,
        *,
        google_tts: Optional[GoogleTTSService] = None,
        deepgram_tts: Optional[DeepgramTTSService] = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.google_tts = google_tts or GoogleTTSService(self.settings)
        self.deepgram_tts = deepgram_tts or DeepgramTTSService(self.settings)

    async def synthesize_speech(
        self,
        text: str,
        *,
        language_code: Optional[str] = None,
    ) -> dict[str, Any]:
        active = language_code or self.settings.google_tts_language_code
        if self._use_deepgram_spanish(active):
            try:
                return await self.deepgram_tts.synthesize_speech(
                    text,
                    model=self.settings.deepgram_tts_model_es,
                    language_code=locale_to_tts_code("es"),
                )
            except DeepgramTTSServiceError as error:
                raise GoogleTTSServiceError(
                    error.detail,
                    status_code=error.status_code,
                ) from error
        return await self.google_tts.synthesize_speech(
            text,
            language_code=active,
        )

    async def _access_token(self) -> str:
        """Warm Google credentials when English TTS may be used."""
        return await self.google_tts._access_token()

    def _use_deepgram_spanish(self, language_code: Optional[str]) -> bool:
        if not self.settings.deepgram_tts_spanish_enabled:
            return False
        if not self.settings.deepgram_api_key:
            return False
        language = normalize_locale(language_code) or ""
        return language == "es"

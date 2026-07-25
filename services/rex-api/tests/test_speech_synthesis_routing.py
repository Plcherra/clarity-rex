import base64

import httpx
import pytest

from app.config import Settings
from app.services.deepgram_tts_service import DeepgramTTSService, DeepgramTTSServiceError
from app.services.google_tts_service import GoogleTTSService
from app.services.speech_synthesis_service import SpeechSynthesisService


def make_response(status_code=200, content=b"mp3-bytes", json_data=None, text=None):
    request = httpx.Request("POST", "https://api.deepgram.com/v1/speak")
    if json_data is not None:
        return httpx.Response(status_code, json=json_data, request=request)
    if text is not None:
        return httpx.Response(status_code, text=text, request=request)
    return httpx.Response(status_code, content=content, request=request)


def configured_settings(**overrides):
    values = {
        "deepgram_api_key": "dg-key",
        "deepgram_tts_spanish_enabled": True,
        "deepgram_tts_model_es": "aura-2-gloria-es",
        "deepgram_tts_encoding": "mp3",
        "google_tts_project_id": "rex-voice",
        "google_tts_credentials_json": '{"type":"service_account"}',
        "google_tts_voice_name": "en-US-Neural2-J",
        "google_tts_language_code": "en-US",
    }
    values.update(overrides)
    return Settings(_env_file=None, **values)


@pytest.mark.asyncio
async def test_deepgram_tts_posts_speak_with_gloria_model(monkeypatch):
    calls = []

    async def fake_request(method, url, **kwargs):
        calls.append({"method": method, "url": url, **kwargs})
        return make_response(content=b"fake-mp3")

    monkeypatch.setattr(
        "app.services.deepgram_tts_service.request_with_retries",
        fake_request,
    )
    service = DeepgramTTSService(configured_settings())
    result = await service.synthesize_speech(
        "Hola, ¿cómo estás?",
        language_code="es",
    )

    assert result["voice_name"] == "aura-2-gloria-es"
    assert result["language_code"] == "es"
    assert result["audio_encoding"] == "MP3"
    assert result["audio_content_type"] == "audio/mpeg"
    assert result["audio_base64"] == base64.b64encode(b"fake-mp3").decode("ascii")
    assert result["metadata"]["vendor"] == "deepgram_aura"
    assert calls[0]["method"] == "POST"
    assert calls[0]["url"] == "https://api.deepgram.com/v1/speak"
    assert calls[0]["params"]["model"] == "aura-2-gloria-es"
    assert calls[0]["json"]["text"] == "Hola, ¿cómo estás?"
    assert calls[0]["headers"]["Authorization"] == "Token dg-key"


@pytest.mark.asyncio
async def test_speech_synthesis_routes_spanish_to_deepgram(monkeypatch):
    deepgram_calls = []

    class FakeDeepgram:
        async def synthesize_speech(self, text, *, model=None, language_code=None):
            deepgram_calls.append(
                {"text": text, "model": model, "language_code": language_code}
            )
            return {
                "audio_content_type": "audio/mpeg",
                "audio_base64": "YQ==",
                "audio_encoding": "MP3",
                "voice_name": model,
                "language_code": language_code,
                "metadata": {"vendor": "deepgram_aura"},
            }

    class FakeGoogle:
        async def synthesize_speech(self, text, *, language_code=None):
            raise AssertionError("Google TTS should not run for Spanish")

    service = SpeechSynthesisService(
        configured_settings(),
        google_tts=FakeGoogle(),
        deepgram_tts=FakeDeepgram(),
    )
    result = await service.synthesize_speech("Buenos días", language_code="es-US")

    assert result["voice_name"] == "aura-2-gloria-es"
    assert deepgram_calls == [
        {
            "text": "Buenos días",
            "model": "aura-2-gloria-es",
            "language_code": "es",
        }
    ]


@pytest.mark.asyncio
async def test_speech_synthesis_keeps_english_on_google(monkeypatch):
    google_calls = []

    class FakeDeepgram:
        async def synthesize_speech(self, *args, **kwargs):
            raise AssertionError("Deepgram should not run for English")

    class FakeGoogle:
        async def synthesize_speech(self, text, *, language_code=None):
            google_calls.append({"text": text, "language_code": language_code})
            return {
                "audio_content_type": "audio/mpeg",
                "audio_base64": "YQ==",
                "audio_encoding": "MP3",
                "voice_name": "en-US-Neural2-J",
                "language_code": language_code or "en-US",
                "metadata": {"vendor": "google_tts"},
            }

    service = SpeechSynthesisService(
        configured_settings(),
        google_tts=FakeGoogle(),
        deepgram_tts=FakeDeepgram(),
    )
    result = await service.synthesize_speech("Hello", language_code="en-US")

    assert result["voice_name"] == "en-US-Neural2-J"
    assert google_calls == [{"text": "Hello", "language_code": "en-US"}]


@pytest.mark.asyncio
async def test_deepgram_tts_requires_api_key():
    service = DeepgramTTSService(Settings(_env_file=None, deepgram_api_key=None))

    with pytest.raises(DeepgramTTSServiceError) as exc_info:
        await service.synthesize_speech("Hola")

    assert exc_info.value.status_code == 503

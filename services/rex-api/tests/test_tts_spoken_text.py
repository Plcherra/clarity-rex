from app.services.tts_spoken_text import prepare_spoken_text
from app.services.voice_stream_orchestrator_support import voice_speakable_text


def test_prepare_spoken_text_strips_emojis():
    assert (
        prepare_spoken_text("Hola 😊 ¿cómo estás? 🙌")
        == "Hola ¿cómo estás?"
    )


def test_prepare_spoken_text_keeps_plain_text():
    assert prepare_spoken_text("  Buenos días.  ") == "Buenos días."


def test_voice_speakable_text_strips_emojis_from_reply():
    assert (
        voice_speakable_text("Listo ✅ vamos 💪", None) == "Listo vamos"
    )

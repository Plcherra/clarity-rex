from app.services.voice_stream_response_writer import VoiceStreamResponseWriterMixin


class _ChunkProbe(VoiceStreamResponseWriterMixin):
    pass


def test_voice_chunker_does_not_split_short_sentence_fragments():
    probe = _ChunkProbe()

    chunk, rest = probe._next_speakable_chunk("Cool. I can help with that. ")

    assert chunk is None
    assert rest == "Cool. I can help with that. "


def test_voice_chunker_splits_at_substantial_sentence_boundary():
    probe = _ChunkProbe()
    text = (
        "Got it, you are canceling the movie because money is tight tonight. "
        "I can help you keep the evening simple."
    )

    chunk, rest = probe._next_speakable_chunk(text)

    assert chunk == (
        "Got it, you are canceling the movie because money is tight tonight."
    )
    assert rest.strip() == "I can help you keep the evening simple."


def test_voice_chunker_uses_word_boundary_for_long_text_without_punctuation():
    probe = _ChunkProbe()
    text = " ".join(["steady"] * 45)

    chunk, rest = probe._next_speakable_chunk(text)

    assert chunk is not None
    assert 36 <= len(chunk) <= 140
    assert rest.strip().startswith("steady")


def test_voice_chunker_starts_audio_after_short_voice_sentence():
    probe = _ChunkProbe()
    text = "Yes, I can help you with that. Tell me what changed."

    chunk, rest = probe._next_speakable_chunk(text)

    assert chunk == "Yes, I can help you with that. Tell me what changed."
    assert rest == ""

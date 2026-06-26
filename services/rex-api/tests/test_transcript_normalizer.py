import pytest

from app.services.transcript_normalizer import TranscriptNormalizer


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        (
            "Don't you know the games ai bought?",
            "do you know the games I bought?",
        ),
        (
            "dont you remember what i told you",
            "do you remember what i told you",
        ),
        (
            "I cant find my gog games",
            "I can't find my GOG games",
        ),
        (
            "The 8bitdo pro 3 is awesome",
            "The 8BitDo pro 3 is awesome",
        ),
        (
            "  chet   history  ",
            "chat history",
        ),
        (
            "im going to buy a game on steam",
            "I'm going to buy a game on Steam",
        ),
    ],
)
def test_transcript_normalizer_fixes_common_voice_and_chat_typos(raw, expected):
    normalizer = TranscriptNormalizer()

    assert normalizer.normalize(raw) == expected


def test_transcript_normalizer_preserves_plain_text():
    normalizer = TranscriptNormalizer()

    assert (
        normalizer.normalize("What is my balance this month?")
        == "What is my balance this month?"
    )
    assert normalizer.normalize("Hello Rex") == "Hello Rex"


def test_transcript_normalizer_matching_view_is_lowercase():
    normalizer = TranscriptNormalizer()

    assert (
        normalizer.normalize_for_matching("Don't you know the games ai bought?")
        == "do you know the games i bought?"
    )

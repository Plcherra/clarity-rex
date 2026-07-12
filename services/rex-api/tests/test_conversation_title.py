from app.services.conversation_title import (
    CONVERSATION_TITLE_MAX_LENGTH,
    clamp_conversation_title,
    derive_conversation_title,
)


def test_derive_conversation_title_trims_and_collapses_whitespace():
    assert (
        derive_conversation_title("  Hello   world  from  Rex  ")
        == "Hello world from Rex"
    )


def test_derive_conversation_title_truncates_long_messages():
    content = (
        "I need help thinking through my budget for this month and next "
        "because rent went up again and groceries are expensive"
    )
    title = derive_conversation_title(content, max_length=40)
    assert len(title) <= 40
    assert title.endswith("…")
    assert " " not in title[-2:]


def test_derive_conversation_title_default_cap():
    content = (
        "This is a very long first message that should become a short "
        "sidebar title so it does not crowd the chats list forever"
    )
    title = derive_conversation_title(content)
    assert len(title) <= CONVERSATION_TITLE_MAX_LENGTH
    assert title.endswith("…")


def test_clamp_conversation_title_empty_custom_fallback():
    assert clamp_conversation_title("  ", empty_fallback="") == ""


def test_derive_conversation_title_empty_falls_back():
    assert derive_conversation_title("   ") == "New conversation"

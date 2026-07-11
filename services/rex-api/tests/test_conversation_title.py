from app.services.conversation_title import derive_conversation_title


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


def test_derive_conversation_title_empty_falls_back():
    assert derive_conversation_title("   ") == "New conversation"

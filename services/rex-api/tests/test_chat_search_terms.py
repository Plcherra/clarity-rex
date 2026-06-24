import pytest

from app.services.chat_search_terms import ChatSearchTermBuilder


@pytest.mark.parametrize(
    ("message", "expected_query"),
    [
        (
            "What did I say about the phrase blue cactus ledger?",
            "blue cactus ledger",
        ),
        (
            "Pull up what I said about Legacy of Kain and payroll.",
            "legacy of kain and payroll",
        ),
        (
            "Search chats for exact words silver mango receipt.",
            "silver mango receipt",
        ),
        (
            "What did I say about Bom Dough payroll and immigration?",
            "bom dough payroll and immigration",
        ),
    ],
)
def test_assistant_topic_query_keeps_exact_and_compound_topics(
    message,
    expected_query,
):
    builder = ChatSearchTermBuilder()

    assert builder.assistant_topic_query(message) == expected_query


def test_assistant_topic_query_falls_back_to_content_terms_without_subject_marker():
    builder = ChatSearchTermBuilder()

    assert builder.assistant_topic_query("Could you pull up Omen PC 45L?") == (
        "omen pc 45l"
    )


def test_search_terms_expand_common_recall_aliases():
    builder = ChatSearchTermBuilder()

    mom_terms = builder.search_terms("mom birthday", max_terms=12)
    gift_terms = builder.search_terms("gift for her", max_terms=12)
    pc_terms = builder.search_terms("PC model", max_terms=12)

    assert {"mom", "mother", "mama"} <= set(mom_terms)
    assert {"gift", "money", "cash"} <= set(gift_terms)
    assert {"pc", "computer", "desktop"} <= set(pc_terms)

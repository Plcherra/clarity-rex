import pytest

from app.services.recall_intent_helper import RecallIntentHelper


@pytest.mark.parametrize(
    ("message", "expected_query"),
    [
        (
            "Could you dig up anything regarding my old Omen build?",
            "omen build",
        ),
        (
            "Can you look back on my mom's birthday and the money amount?",
            "mom's birthday and money amount",
        ),
        (
            "What did I say about the phrase blue cactus ledger?",
            "blue cactus ledger",
        ),
        (
            "Pull up what I said about Legacy of Kain and payroll.",
            "legacy of kain and payroll",
        ),
    ],
)
def test_recall_helper_extracts_generic_topic_queries(message, expected_query):
    helper = RecallIntentHelper()

    assert helper.is_recall_request(message, conversation_history=[]) is True
    assert helper.recall_search_query(
        message,
        conversation_history=[],
    ) == expected_query


@pytest.mark.parametrize(
    "message",
    [
        "I bought a blue cactus ledger today.",
        "My Omen build is running fine now.",
        "Payroll was slow this week.",
        "Tell me about Python decorators.",
        "Find a dentist near me.",
        "Look for budgeting tips.",
        "Search the web for exchange rates.",
        "What about dinner ideas?",
    ],
)
def test_recall_helper_does_not_search_for_plain_topic_mentions(message):
    helper = RecallIntentHelper()

    assert helper.is_recall_request(message, conversation_history=[]) is False
    assert helper.recall_search_query(message, conversation_history=[]) is None


@pytest.mark.parametrize(
    ("message", "expected_query"),
    [
        ("Search chats for blue cactus ledger.", "blue cactus ledger"),
        ("Look through old chats for budgeting tips.", "budgeting tips"),
        ("What information do you have regarding payroll?", "payroll"),
        ("Do you know anything about my Omen build?", "omen build"),
    ],
)
def test_recall_helper_keeps_clear_recall_and_chat_search_intent(
    message,
    expected_query,
):
    helper = RecallIntentHelper()

    assert helper.is_recall_request(message, conversation_history=[]) is True
    assert helper.recall_search_query(
        message,
        conversation_history=[],
    ) == expected_query

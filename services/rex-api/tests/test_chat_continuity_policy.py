import pytest

from app.services.chat_context_recall import ChatContextRecallPolicy
from app.services.chat_continuity_policy import ChatContinuityPolicy


@pytest.mark.parametrize(
    ("message", "expected_query"),
    [
        (
            "Do you think the 8BitDo Pro 3 would be good enough for the games I bought?",
            "games",
        ),
        (
            "Would it work for games I purchased?",
            "games",
        ),
        (
            "What did I buy on GOG last week?",
            "gog last week",
        ),
        (
            "Is that controller good for the game I wanted?",
            "game",
        ),
    ],
)
def test_continuity_policy_searches_when_question_assumes_prior_context(
    message,
    expected_query,
):
    policy = ChatContextRecallPolicy()

    assert policy.needs_chat_search(message, conversation_history=[]) is True
    query = policy.recall_query(message, conversation_history=[])
    assert query is not None
    assert expected_query in query


@pytest.mark.parametrize(
    "message",
    [
        "I bought a blue cactus ledger today.",
        "My Omen build is running fine now.",
        "Tell me about Python decorators.",
        "What should I eat for dinner?",
        "Would the controller work well?",
        "Do you think this desk layout looks clean?",
    ],
)
def test_continuity_policy_skips_plain_or_non_user_scoped_turns(message):
    policy = ChatContinuityPolicy()

    assert policy.needs_cross_chat_lookup(message, conversation_history=[]) is False


def test_continuity_policy_skips_when_topic_is_already_in_current_chat():
    policy = ChatContinuityPolicy()
    history = [
        {
            "role": "user",
            "content": "I picked up Legacy of Kain and Soul Reaver on GOG yesterday.",
        },
        {
            "role": "assistant",
            "content": "Nice picks for classic action-adventure.",
        },
    ]

    assert (
        policy.needs_cross_chat_lookup(
            "Would the 8BitDo work for the games I bought?",
            conversation_history=history,
        )
        is False
    )


def test_continuity_policy_searches_when_current_chat_lacks_topic_terms():
    policy = ChatContinuityPolicy()
    history = [
        {
            "role": "user",
            "content": "Here is a photo of my desk and PC setup.",
        },
        {
            "role": "assistant",
            "content": "The dual monitors look clean.",
        },
    ]

    assert (
        policy.needs_cross_chat_lookup(
            "Would the 8BitDo work for the games I bought?",
            conversation_history=history,
        )
        is True
    )

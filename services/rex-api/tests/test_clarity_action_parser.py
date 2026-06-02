from app.services.clarity_action_parser import (
    ClarityActionParser,
    ClarityActionStreamFilter,
)


def test_clarity_action_parser_extracts_proposal_and_cleans_response():
    parser = ClarityActionParser()

    cleaned, proposals = parser.extract_proposals(
        "Confirm moving it?\n\n"
        "```clarity_action\n"
        '{"action":"update_transaction",'
        '"payload":{"id":"transaction-1"},'
        '"confirmation_text":"Update transaction?",'
        '"risk_level":"high"}'
        "\n```"
    )

    assert cleaned == "Confirm moving it?"
    assert proposals == [
        {
            "id": "clarity-action-1",
            "action": "update_transaction",
            "payload": {"id": "transaction-1"},
            "confirmation_text": "Update transaction?",
            "risk_level": "high",
            "status": "pending",
        }
    ]


def test_clarity_action_parser_ignores_malformed_or_incomplete_blocks():
    parser = ClarityActionParser()

    cleaned, proposals = parser.extract_proposals(
        "Before\n\n```clarity_action\nnot json\n```\nAfter"
    )
    assert cleaned == "Before\n\n\nAfter"
    assert proposals == []

    cleaned, proposals = parser.extract_proposals(
        "Before\n\n```clarity_action\n{\"action\":\"missing_payload\"}\n```\nAfter"
    )
    assert cleaned == "Before\n\n\nAfter"
    assert proposals == []


def test_clarity_action_parser_merges_proposals_into_memory_changes():
    parser = ClarityActionParser()
    proposal = {
        "id": "clarity-action-1",
        "action": "update_transaction",
        "payload": {"id": "transaction-1"},
        "confirmation_text": "Update transaction?",
        "risk_level": "medium",
        "status": "pending",
    }

    assert parser.with_memory_changes(None, []) is None
    assert parser.with_memory_changes(None, [proposal]) == {
        "clarity_action_proposals": [proposal]
    }
    assert parser.with_memory_changes({"created": 1}, [proposal]) == {
        "created": 1,
        "clarity_action_proposals": [proposal],
    }


def test_clarity_action_stream_filter_hides_action_block_across_tokens():
    stream_filter = ClarityActionStreamFilter()
    visible = []

    for token in [
        "I found it. ```clar",
        "ity_action\n",
        '{"action":"update_transaction","payload":{"id":"t1"}}',
        "\n``` Done.",
    ]:
        visible.extend(stream_filter.feed(token))
    visible.extend(stream_filter.finish())

    text = "".join(visible)
    assert text == "I found it.  Done."
    assert "clarity_action" not in text
    assert "update_transaction" not in text

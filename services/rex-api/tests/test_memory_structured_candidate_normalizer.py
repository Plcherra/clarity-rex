from app.services.memory_structured_candidate_normalizer import (
    MemoryStructuredCandidateNormalizer,
    clean_list,
    looks_like_vague_entity,
    normalized_text,
)


def test_structured_candidate_normalizer_normalizes_entity_candidate():
    normalizer = MemoryStructuredCandidateNormalizer()

    result = normalizer.normalize_entity(
        {
            "entity_type": "person",
            "display_name": "  Mom  ",
            "aliases": ["mother", "Mother"],
            "relationship": "family",
            "importance": 5,
            "rationale": "Important family context",
        },
        conversation_id="conversation-1",
        user_message_id="message-1",
    )

    assert result["payload"]["display_name"] == "Mom"
    assert result["payload"]["aliases"] == ["mother"]
    assert result["payload"]["source_conversation_id"] == "conversation-1"
    assert result["rationale"] == "Important family context"


def test_structured_candidate_normalizer_rejects_vague_entity_candidate():
    normalizer = MemoryStructuredCandidateNormalizer()

    assert looks_like_vague_entity("someone")
    assert normalizer.normalize_entity(
        {
            "entity_type": "person",
            "display_name": "someone",
            "importance": 5,
        },
        conversation_id="conversation-1",
        user_message_id="message-1",
    ) is None


def test_structured_candidate_normalizer_normalizes_commitment_candidate():
    normalizer = MemoryStructuredCandidateNormalizer()

    result = normalizer.normalize_commitment(
        {
            "commitment_type": "task",
            "title": " Send mom a gift ",
            "commitment_text": "Send mom something for her birthday",
            "due_at": "2026-06-18",
            "priority": 4,
        },
        conversation_id="conversation-1",
        user_message_id="message-1",
    )

    assert result["payload"]["title"] == "Send mom a gift"
    assert result["payload"]["due_at"] == "2026-06-18"
    assert result["payload"]["priority"] == 4


def test_structured_candidate_text_helpers_are_stable():
    assert normalized_text(" Mom's Birthday!! ") == "mom s birthday"
    assert clean_list([" coffee ", "Coffee", "", None]) == ["coffee"]

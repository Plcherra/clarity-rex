from app.services.memory_extraction_parser import (
    MemoryExtractionParser,
    looks_noisy,
)


def test_memory_extraction_parser_extracts_fenced_json_payload():
    parser = MemoryExtractionParser()

    payload = parser.parse_extraction_payload(
        '```json\n{"memories": [{"memory_type": "fact", "content": "Pedro lives in New York", "importance": 4}]}\n```'
    )

    assert payload["memories"][0]["content"] == "Pedro lives in New York"


def test_memory_extraction_parser_filters_invalid_structured_sections():
    parser = MemoryExtractionParser()

    payload = parser.parse_extraction_payload(
        '{"structured_memories": {"entities": [{"display_name": "Mom"}], "unknown": [{"bad": true}], "plans": "bad"}}'
    )

    assert payload["structured_memories"]["entities"] == [{"display_name": "Mom"}]
    assert "unknown" not in payload["structured_memories"]
    assert "plans" not in payload["structured_memories"]


def test_memory_extraction_parser_normalizes_valid_candidate():
    parser = MemoryExtractionParser()

    candidate = parser.normalize_candidate(
        {
            "memory_type": " Fact ",
            "content": "  Mom's birthday is June 18  ",
            "importance": "5",
            "rationale": "",
        }
    )

    assert candidate == {
        "memory_type": "fact",
        "content": "Mom's birthday is June 18",
        "importance": 5,
        "rationale": "Useful future context.",
    }


def test_memory_extraction_parser_rejects_noisy_candidate():
    parser = MemoryExtractionParser()

    assert looks_noisy("The user asked Rex to answer the current question")
    assert parser.normalize_candidate(
        {
            "memory_type": "fact",
            "content": "The user asked Rex to answer the current question",
            "importance": 5,
        }
    ) is None

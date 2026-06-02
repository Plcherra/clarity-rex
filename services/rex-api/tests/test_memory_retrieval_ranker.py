from app.services.memory_retrieval_ranker import MemoryRetrievalRanker


def test_ranker_scores_relevant_profile_fact():
    ranker = MemoryRetrievalRanker()
    query_terms = ranker.expanded_terms("What do you know about my profile?")

    scored = ranker.score_memory(
        {
            "id": "memory-profile",
            "memory_type": "fact",
            "content": "Pedro lives in Massachusetts and prefers concise answers.",
            "importance": 5,
            "created_at": "2026-05-01T10:00:00Z",
        },
        query_terms,
    )

    assert scored is not None
    assert scored["relevance_score"] > 0
    assert scored["relevance_reason"] == "Included high-priority profile fact."


def test_ranker_filters_stale_corrected_memory():
    ranker = MemoryRetrievalRanker()
    memories = [
        {
            "id": "old-memory",
            "content": "The project is called Flowfirst.",
            "relevance_score": 0.9,
        },
        {
            "id": "correction-memory",
            "content": "The project is called FlowForce, not Flowfirst.",
            "relevance_score": 1.0,
        },
    ]

    filtered = ranker.filter_stale_corrected_memories(memories)

    assert [memory["id"] for memory in filtered] == ["correction-memory"]


def test_ranker_includes_high_priority_structured_record():
    ranker = MemoryRetrievalRanker()

    records = ranker.rank_structured_records(
        [
            {
                "id": "rule-1",
                "title": "Keep summaries concise",
                "rule_text": "Prefer concise executive summaries.",
                "priority": 5,
                "status": "active",
                "created_at": "2026-05-01T10:00:00Z",
            },
        ],
        query_terms=set(),
        text_fields=("title", "rule_text"),
        weight_field="priority",
        status_values={"active"},
        include_high_priority=True,
    )

    assert records[0]["id"] == "rule-1"
    assert records[0]["relevance_reason"] == (
        "Included high-priority active structured memory."
    )


def test_ranker_merges_related_records_without_duplicates():
    ranker = MemoryRetrievalRanker()

    merged = ranker.merge_related_records(
        [{"id": "entity-1", "display_name": "Mom"}],
        [
            {"id": "entity-1", "display_name": "Mom duplicate"},
            {"id": "entity-2", "display_name": "Dad"},
        ],
    )

    assert [record["id"] for record in merged] == ["entity-1", "entity-2"]
    assert merged[1]["relevance_reason"] == "Included through linked structured memory."

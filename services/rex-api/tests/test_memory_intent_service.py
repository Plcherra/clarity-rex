from app.services.memory_intent_service import (
    MemoryIntentService,
    SimpleMemoryIntent,
)


def test_detects_birthday_with_current_month_context():
    service = MemoryIntentService()

    intent = service.detect_simple_memory(
        "My mom's birthday is on the 18th.",
        time_context={"date": "2026-06-01"},
    )

    assert intent == SimpleMemoryIntent(
        memory_type="fact",
        content="User's mom's birthday is June 18.",
        importance=5,
        confirmation_question="So your mom's birthday is June 18, correct?",
        metadata={
            "fact_kind": "birthday",
            "entity_label": "mom",
            "normalized_date": "June 18",
            "topic_fingerprint": "fact:birthday:mom",
        },
    )


def test_detects_birthday_with_spelled_out_ordinal():
    service = MemoryIntentService()

    intent = service.detect_simple_memory(
        "My mom's birthday is on the eighteenth.",
        time_context={"date": "2026-06-01"},
    )

    assert intent == SimpleMemoryIntent(
        memory_type="fact",
        content="User's mom's birthday is June 18.",
        importance=5,
        confirmation_question="So your mom's birthday is June 18, correct?",
        metadata={
            "fact_kind": "birthday",
            "entity_label": "mom",
            "normalized_date": "June 18",
            "topic_fingerprint": "fact:birthday:mom",
        },
    )


def test_detects_contextual_birthday_date_answer():
    service = MemoryIntentService()

    intent = service.detect_contextual_memory(
        "On the eighteenth.",
        conversation_history=[
            {
                "role": "user",
                "content": "I'm thinking about my mom and her birthday this month.",
            },
            {
                "role": "assistant",
                "content": "Nice, when's her birthday exactly?",
            },
        ],
        time_context={"date": "2026-06-01"},
    )

    assert intent == SimpleMemoryIntent(
        memory_type="fact",
        content="User's mom's birthday is June 18.",
        importance=5,
        confirmation_question="So your mom's birthday is June 18, correct?",
        metadata={
            "fact_kind": "birthday",
            "entity_label": "mom",
            "normalized_date": "June 18",
            "topic_fingerprint": "fact:birthday:mom",
        },
    )


def test_contextual_date_answer_needs_birthday_context():
    service = MemoryIntentService()

    assert (
        service.detect_contextual_memory(
            "On the eighteenth.",
            conversation_history=[
                {"role": "user", "content": "I need to send rent."},
                {"role": "assistant", "content": "When is it due?"},
            ],
            time_context={"date": "2026-06-01"},
        )
        is None
    )


def test_detects_birthday_with_explicit_month():
    service = MemoryIntentService()

    intent = service.detect_simple_memory(
        "My mother's birthday is March 4.",
        time_context={"date": "2026-06-01"},
    )

    assert intent == SimpleMemoryIntent(
        memory_type="fact",
        content="User's mom's birthday is March 4.",
        importance=5,
        confirmation_question="So your mom's birthday is March 4, correct?",
        metadata={
            "fact_kind": "birthday",
            "entity_label": "mom",
            "normalized_date": "March 4",
            "topic_fingerprint": "fact:birthday:mom",
        },
    )


def test_detects_explicit_remember_that_fact():
    service = MemoryIntentService()

    intent = service.detect_simple_memory(
        "Please remember that I work best in the morning.",
    )

    assert intent == SimpleMemoryIntent(
        memory_type="fact",
        content="I work best in the morning.",
        importance=4,
        confirmation_question="Should I remember that I work best in the morning?",
        metadata={
            "fact_kind": "remember_that",
            "topic_fingerprint": "fact:remember_that:i_work_best_in_the_morning",
        },
    )


def test_ignores_messages_without_simple_memory_intent():
    service = MemoryIntentService()

    assert service.detect_simple_memory("Can you help me plan today?") is None
    assert service.detect_simple_memory("Remember.") is None


def test_classifies_confirmation_and_rejection_replies():
    service = MemoryIntentService()

    assert service.classify_confirmation_reply("yes") == "confirm"
    assert service.classify_confirmation_reply("Yeah, save it") == "confirm"
    assert service.classify_confirmation_reply("that's right") == "confirm"
    assert service.classify_confirmation_reply("no") == "reject"
    assert service.classify_confirmation_reply("Nope, don't save it") == "reject"
    assert service.classify_confirmation_reply("what do you mean?") is None


def test_confirmation_marker_round_trips_and_strips_from_public_text():
    service = MemoryIntentService()
    intent = SimpleMemoryIntent(
        memory_type="fact",
        content="User's mom's birthday is June 18.",
        importance=5,
        confirmation_question="So your mom's birthday is June 18, correct?",
        metadata={"fact_kind": "birthday"},
    )

    stored_text = service.with_confirmation_marker(
        "So your mom's birthday is June 18, correct?",
        intent,
    )

    assert "rex_memory_confirmation" in stored_text
    assert service.strip_internal_markers(stored_text) == (
        "So your mom's birthday is June 18, correct?"
    )
    assert service.confirmation_payload(stored_text) == {
        "memory_type": "fact",
        "content": "User's mom's birthday is June 18.",
        "importance": 5,
        "source": "simple_memory_intent",
        "metadata": {"fact_kind": "birthday"},
    }


def test_pending_confirmation_only_reads_last_assistant_marker():
    service = MemoryIntentService()
    marked_text = service.with_confirmation_marker(
        "So your mom's birthday is June 18, correct?",
        SimpleMemoryIntent(
            memory_type="fact",
            content="User's mom's birthday is June 18.",
            importance=5,
            confirmation_question="So your mom's birthday is June 18, correct?",
            metadata={"fact_kind": "birthday"},
        ),
    )

    pending = service.pending_confirmation_from_history(
        [
            {"role": "user", "content": "My mom's birthday is June 18"},
            {"role": "assistant", "content": marked_text},
        ]
    )

    assert pending == SimpleMemoryIntent(
        memory_type="fact",
        content="User's mom's birthday is June 18.",
        importance=5,
        confirmation_question="",
        metadata={"fact_kind": "birthday"},
    )
    assert (
        service.pending_confirmation_from_history(
            [
                {"role": "assistant", "content": marked_text},
                {"role": "user", "content": "What else can you do?"},
            ]
        )
        is None
    )
    assert (
        service.pending_confirmation_from_history(
            [{"role": "assistant", "content": "No marker here."}]
        )
        is None
    )


def test_malformed_confirmation_marker_is_ignored():
    service = MemoryIntentService()
    malformed = "Question?\n\n<!-- rex_memory_confirmation:not-valid-base64 -->"

    assert service.confirmation_payload(malformed) is None
    assert (
        service.pending_confirmation_from_history(
            [{"role": "assistant", "content": malformed}]
        )
        is None
    )

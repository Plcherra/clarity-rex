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
        metadata={
            "fact_kind": "remember_that",
            "topic_fingerprint": "fact:remember_that:i_work_best_in_the_morning",
        },
    )


def test_detects_precise_movie_plan_with_speech_title_normalization():
    service = MemoryIntentService()

    intent = service.detect_simple_memory(
        "Today, they released the messes of the universe movie. I'm gonna watch.",
    )

    assert intent == SimpleMemoryIntent(
        memory_type="event",
        content="User plans to watch Masters of the Universe movie today.",
        importance=3,
        metadata={
            "fact_kind": "personal_plan",
            "topic_fingerprint": (
                "event:personal_plan:"
                "user_plans_to_watch_masters_of_the_universe_movie_today"
            ),
        },
    )


def test_detects_precise_movie_plan_with_exact_title():
    service = MemoryIntentService()

    intent = service.detect_simple_memory(
        "Tonight they released the Masters of the Universe movie and I plan to watch.",
    )

    assert intent is not None
    assert intent.content == "User plans to watch Masters of the Universe movie tonight."
    assert intent.metadata["fact_kind"] == "personal_plan"


def test_detects_preference_comparison():
    service = MemoryIntentService()

    intent = service.detect_simple_memory("I prefer tea over coffee.")

    assert intent == SimpleMemoryIntent(
        memory_type="preference",
        content="User prefers tea over coffee.",
        importance=4,
        metadata={
            "fact_kind": "preference",
            "preferred": "tea",
            "compared_to": "coffee",
            "topic_fingerprint": "preference:tea:coffee",
        },
    )


def test_ignores_messages_without_simple_memory_intent():
    service = MemoryIntentService()

    assert service.detect_simple_memory("Can you help me plan today?") is None
    assert service.detect_simple_memory("Remember.") is None

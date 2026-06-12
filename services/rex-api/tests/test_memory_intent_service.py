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


def test_detects_inverted_birthday_phrase_with_spelled_out_ordinal():
    service = MemoryIntentService()

    intent = service.detect_simple_memory(
        "It's not next week, but on the eighteenth, it's my mom's birthday.",
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


def test_detects_family_birthday_correction_without_my_prefix():
    service = MemoryIntentService()

    intent = service.detect_simple_memory(
        "No, mom's birthday is June 28.",
        time_context={"date": "2026-06-01"},
    )

    assert intent == SimpleMemoryIntent(
        memory_type="fact",
        content="User's mom's birthday is June 28.",
        importance=5,
        metadata={
            "fact_kind": "birthday",
            "entity_label": "mom",
            "normalized_date": "June 28",
            "topic_fingerprint": "fact:birthday:mom",
        },
    )


def test_detects_negative_location_correction_phrase():
    service = MemoryIntentService()

    intent = service.detect_simple_memory(
        "I don't live in Summerville. It's Somerville with one o and one m.",
    )

    assert intent == SimpleMemoryIntent(
        memory_type="fact",
        content="User lives in Somerville.",
        importance=4,
        metadata={
            "fact_kind": "location",
            "topic_fingerprint": "fact:identity:location",
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
        content="User plans to watch Masters of the Universe today.",
        importance=3,
        metadata={
            "fact_kind": "personal_plan",
            "plan_action": "watch",
            "plan_title": "Masters of the Universe",
            "plan_time": "today",
            "plan_status": "planned",
            "topic_fingerprint": "event:personal_plan:watch:masters_of_the_universe",
        },
    )


def test_detects_precise_movie_plan_with_exact_title():
    service = MemoryIntentService()

    intent = service.detect_simple_memory(
        "Tonight they released the Masters of the Universe movie and I plan to watch.",
    )

    assert intent is not None
    assert intent.content == "User plans to watch Masters of the Universe tonight."
    assert intent.metadata["fact_kind"] == "personal_plan"


def test_detects_released_title_when_watch_uses_it_later():
    service = MemoryIntentService()

    intent = service.detect_simple_memory(
        "They just released Masters of the Universe, and I'm gonna watch it tonight."
    )

    assert intent is not None
    assert intent.content == "User plans to watch Masters of the Universe tonight."
    assert intent.metadata["topic_fingerprint"] == (
        "event:personal_plan:watch:masters_of_the_universe"
    )


def test_detects_ticket_update_from_recent_plan_context():
    service = MemoryIntentService()

    intent = service.detect_contextual_memory(
        "I already bought the tickets.",
        conversation_history=[
            {
                "role": "assistant",
                "content": "Got it, you plan to watch Masters of the Universe tonight.",
            }
        ],
    )

    assert intent is not None
    assert intent.content == (
        "User plans to watch Masters of the Universe tonight and already bought tickets."
    )
    assert intent.metadata["plan_status"] == "tickets_bought"


def test_detects_canceled_plan_from_recent_plan_context():
    service = MemoryIntentService()

    intent = service.detect_contextual_memory(
        "I gotta cancel that because my money is tight.",
        conversation_history=[
            {
                "role": "assistant",
                "content": "Got it, you plan to watch Masters of the Universe tonight.",
            }
        ],
    )

    assert intent is not None
    assert intent.content == (
        "User canceled the plan to watch Masters of the Universe tonight because money is tight."
    )
    assert intent.metadata["plan_status"] == "canceled"


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

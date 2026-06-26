from app.services.memory_correction_intent_parser import MemoryCorrectionIntentParser
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
            "memory_category": "Events",
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
            "memory_category": "Events",
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
            "memory_category": "Events",
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
            "memory_category": "Events",
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


def test_memory_lookup_or_topic_shift_uses_generic_recall_language():
    service = MemoryIntentService()

    assert service.is_memory_lookup_or_topic_shift(
        "Do you know anything about my cousin Ana?"
    )
    assert service.is_memory_lookup_or_topic_shift(
        "Search old chats about the blue cactus ledger."
    )
    assert not service.is_memory_lookup_or_topic_shift(
        "My cousin Ana's birthday is July 9."
    )
    assert not service.is_memory_lookup_or_topic_shift(
        "No, cousin Ana's birthday is July 9."
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
            "memory_category": "Events",
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
            "memory_category": "Events",
            "entity_label": "mom",
            "normalized_date": "June 28",
            "topic_fingerprint": "fact:birthday:mom",
        },
    )


def test_detects_generic_person_birthday_correction_without_my_prefix():
    service = MemoryIntentService()

    intent = service.detect_simple_memory(
        "No, cousin Ana's birthday is July 9.",
        time_context={"date": "2026-06-01"},
    )

    assert intent == SimpleMemoryIntent(
        memory_type="fact",
        content="User's cousin ana's birthday is July 9.",
        importance=5,
        metadata={
            "fact_kind": "birthday",
            "memory_category": "Events",
            "entity_label": "cousin ana",
            "normalized_date": "July 9",
            "topic_fingerprint": "fact:birthday:cousin ana",
        },
    )


def test_detects_generic_inverted_birthday_phrase():
    service = MemoryIntentService()

    intent = service.detect_simple_memory(
        "On July 9, it's my cousin Ana's birthday.",
        time_context={"date": "2026-06-01"},
    )

    assert intent is not None
    assert intent.content == "User's cousin ana's birthday is July 9."
    assert intent.metadata["entity_label"] == "cousin ana"
    assert intent.metadata["topic_fingerprint"] == "fact:birthday:cousin ana"


def test_detects_contextual_birthday_date_answer_for_generic_person():
    service = MemoryIntentService()

    intent = service.detect_contextual_memory(
        "On July 9.",
        conversation_history=[
            {
                "role": "user",
                "content": "I need to remember my cousin Ana's birthday.",
            },
            {
                "role": "assistant",
                "content": "What day is your cousin Ana's birthday?",
            },
        ],
        time_context={"date": "2026-06-01"},
    )

    assert intent is not None
    assert intent.content == "User's cousin ana's birthday is July 9."
    assert intent.metadata["entity_label"] == "cousin ana"


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
            "memory_category": "Places",
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
            "memory_category": "Facts",
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
            "memory_category": "Goals",
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
            "memory_category": "Preferences",
            "preferred": "tea",
            "compared_to": "coffee",
            "topic_fingerprint": "preference:tea:coffee",
        },
    )


def test_ignores_messages_without_simple_memory_intent():
    service = MemoryIntentService()

    assert service.detect_simple_memory("Can you help me plan today?") is None
    assert service.detect_simple_memory("Remember.") is None


def test_simple_memory_intents_cover_allowed_categories():
    service = MemoryIntentService()

    cases = [
        ("My name is Pedro Martins.", "People"),
        ("My mom's birthday is June 18.", "Events"),
        ("My birthday is June 18.", "Events"),
        ("I live in Somerville.", "Places"),
        ("I work at Bom Dough.", "People"),
        ("I prefer tea over coffee.", "Preferences"),
        (
            "Today, they released the Masters of the Universe movie and I plan to watch.",
            "Goals",
        ),
        ("Please remember that I work best in the morning.", "Facts"),
    ]

    for message, expected_category in cases:
        intent = service.detect_simple_memory(
            message,
            time_context={"date": "2026-06-01"},
        )
        assert intent is not None
        assert intent.metadata["memory_category"] == expected_category


def test_detects_relationship_person_save_request():
    service = MemoryIntentService()

    intent = service.detect_simple_memory("Can you save my best friend Pedro?")

    assert intent is not None
    assert intent.content == "User's best friend is Pedro."
    assert intent.metadata["fact_kind"] == "relationship"
    assert intent.metadata["entity_label"] == "pedro"


def test_detects_possessive_third_party_birthday():
    service = MemoryIntentService()

    intent = service.detect_simple_memory(
        "Pedro's mom birthday is june 18",
        time_context={"date": "2026-06-01"},
    )

    assert intent is not None
    assert intent.content == "Pedro's Mom's birthday is June 18."
    assert intent.metadata["entity_label"] == "pedro's mom"
    assert intent.metadata["entity_owner"] == "pedro"
    assert intent.metadata["entity_relation"] == "mom"


def test_detects_is_actually_name_correction():
    service = MemoryCorrectionIntentParser()

    intent = service.detect_correction_intent("The S Mom is actually Pedro's Mom")

    assert intent.intent_type.value == "replace_value"
    assert intent.old_value == "S Mom"
    assert intent.new_value == "Pedro's Mom"


def test_yes_after_unrelated_birthday_does_not_reconfirm_birthday():
    service = MemoryIntentService()
    history = [
        {"role": "user", "content": "Can you save my mom's birthday?"},
        {
            "role": "assistant",
            "content": "Sure, what's your mom's birthday date? I'll save it once you confirm.",
        },
        {"role": "user", "content": "Jan 1"},
        {"role": "assistant", "content": "Got it, your mom's birthday is January 1."},
        {"role": "user", "content": "Can you save my best friend Pedro?"},
        {
            "role": "assistant",
            "content": "Want me to save Pedro as your best friend? Confirm with yes.",
        },
    ]

    intent = service.detect_contextual_memory(
        "Yes",
        conversation_history=history,
        time_context={"date": "2026-06-01"},
    )

    assert intent is not None
    assert intent.content == "User's best friend is Pedro."
    assert intent.metadata["fact_kind"] == "relationship"
    service = MemoryIntentService()
    history = [
        {"role": "user", "content": "Can you save my mom's birthday?"},
        {
            "role": "assistant",
            "content": "Sure, what's your mom's birthday date? I'll save it once you confirm.",
        },
        {"role": "user", "content": "Jan 1"},
        {"role": "assistant", "content": "Got it, your mom's birthday is January 1."},
        {"role": "user", "content": "Can you save my best friend Pedro?"},
        {
            "role": "assistant",
            "content": "Want me to save Pedro as your best friend? Confirm with yes.",
        },
    ]

    intent = service.detect_contextual_memory(
        "Yes",
        conversation_history=history,
        time_context={"date": "2026-06-01"},
    )

    assert intent is not None
    assert intent.content == "User's best friend is Pedro."
    assert intent.metadata["fact_kind"] == "relationship"

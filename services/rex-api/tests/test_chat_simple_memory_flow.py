from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from chat_service_fakes import (
    FakeAIService,
    FakeMemoryService,
)
from durable_write_test_helpers import confirm_durable_write, save_message_with_confirmation
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.rex_channel import RexBrainChannel
from app.services.time_context_service import TimeContextService


def _fixed_time_context_service():
    return TimeContextService(
        timezone_name="America/New_York",
        now_provider=lambda: datetime(
            2026,
            6,
            1,
            12,
            0,
            tzinfo=ZoneInfo("America/New_York"),
        ),
    )


def _seed_pedro_mom_entity(
    memory_service,
    *,
    display_name: str = "Pedro's Mom",
    normalized_name: str | None = None,
) -> None:
    memory_service.entities.append(
        {
            "id": "entity-pedro-mom",
            "entity_type": "person",
            "display_name": display_name,
            "normalized_name": normalized_name or display_name.casefold(),
            "relationship": "mother",
            "aliases": [],
            "metadata": {"attributes": {"birthday": "June 18"}},
            "active": True,
        }
    )


@pytest.mark.asyncio
async def test_simple_memory_saves_durable_memory_directly():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    proposed = await chat_service.send_message("My mom's birthday is on the 18th")
    assert proposed["memory_changes"]["confirmation_required"] == 1
    saved = await confirm_durable_write(chat_service, proposed)

    assert "Saved to Clarity Knows" in saved["response"]
    assert saved["memory_changes"]["created"] == 1
    assert saved["memory_changes"]["confirmation_required"] == 0
    assert saved["messages"][-1]["content"] == saved["response"]
    assert ai_service.messages == []
    assert memory_service.long_term_memory[0]["memory_type"] == "fact"
    assert memory_service.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 18."
    )
    assert len(memory_service.entities) == 0

    await chat_service.send_message(
        "Do you remember my mom's birthday?",
        saved["conversation_id"],
    )

    assert "- fact: User's mom's birthday is June 18." in ai_service.messages[0]["content"]


@pytest.mark.asyncio
async def test_inverted_birthday_phrase_saves_durable_memory_directly():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    saved = await save_message_with_confirmation(
        chat_service,
        "It's not next week, but on the eighteenth, it's my mom's birthday.",
    )

    assert "Saved to Clarity Knows" in saved["response"]
    assert saved["memory_changes"]["created"] == 1
    assert saved["memory_changes"]["confirmation_required"] == 0
    assert memory_service.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 18."
    )
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_identity_and_location_facts_save_without_confirmation():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    name_turn = await save_message_with_confirmation(chat_service, "My name is Pedro")
    location_turn = await save_message_with_confirmation(
        chat_service,
        "I live in Somerville",
    )

    assert "Saved to Clarity Knows" in name_turn["response"]
    assert name_turn["memory_changes"]["created"] == 1
    assert "Saved to Clarity Knows" in location_turn["response"]
    assert location_turn["memory_changes"]["created"] == 1
    assert [memory["content"] for memory in memory_service.long_term_memory] == [
        "User's name is Pedro.",
        "User lives in Somerville.",
    ]
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_contextual_birthday_answer_saves_directly():
    ai_service = FakeAIService(response="Nice, when's her birthday exactly?")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    first_turn = await chat_service.send_message(
        "I'm thinking about my mom and her birthday. It is on this month."
    )
    proposed = await chat_service.send_message(
        "On the eighteenth.",
        first_turn["conversation_id"],
    )
    confirmation = await confirm_durable_write(chat_service, proposed)

    assert "Saved to Clarity Knows" in confirmation["response"]
    assert confirmation["memory_changes"]["created"] == 1
    assert confirmation["memory_changes"]["confirmation_required"] == 0
    assert memory_service.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 18."
    )


@pytest.mark.asyncio
async def test_contextual_birthday_month_day_answer_saves_directly():
    ai_service = FakeAIService(response="Sure, what's the date? I'll add it.")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )
    conversation_id = await memory_service.create_conversation()
    await memory_service.save_message(
        conversation_id,
        "user",
        "Do you have any memory about my mom?",
    )
    await memory_service.save_message(
        conversation_id,
        "assistant",
        "No, nothing about your mom in memory yet.",
    )
    await memory_service.save_message(conversation_id, "user", "Maybe her birthday?")
    await memory_service.save_message(
        conversation_id,
        "assistant",
        "Sure, what's the date? I'll add it.",
    )

    proposed = await chat_service.send_message("June 18", conversation_id)
    confirmation = await confirm_durable_write(chat_service, proposed)

    assert "Saved to Clarity Knows" in confirmation["response"]
    assert confirmation["memory_changes"]["created"] == 1
    assert confirmation["memory_changes"]["confirmation_required"] == 0
    assert memory_service.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 18."
    )


@pytest.mark.asyncio
async def test_simple_memory_direct_save_works_in_voice_stream():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    confirmation_events = [
        event
        async for event in chat_service.stream_message(
            "My mom's birthday is June 18",
            channel=RexBrainChannel.VOICE,
        )
    ]

    assert confirmation_events[0] == {
        "event": "conversation",
        "conversation_id": "conversation-1",
    }
    assert confirmation_events[-1]["memory_changes"]["confirmation_required"] == 1
    assert ai_service.messages == []
    assert memory_service.long_term_memory == []

    confirmed = await confirm_durable_write(
        chat_service,
        {
            "conversation_id": confirmation_events[-1]["conversation_id"],
            "memory_changes": confirmation_events[-1]["memory_changes"],
        },
    )
    assert confirmed["memory_changes"]["created"] == 1
    assert memory_service.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 18."
    )

    follow_up_events = [
        event
        async for event in chat_service.stream_message(
            "Do you remember my mom's birthday?",
            conversation_id="conversation-1",
            channel=RexBrainChannel.VOICE,
        )
    ]

    assert follow_up_events[-1]["event"] == "done"
    assert (
        "- fact: User's mom's birthday is June 18."
        in ai_service.messages[0]["content"]
    )


@pytest.mark.asyncio
async def test_voice_stream_directly_updates_location_memory():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User lives in Summerville, Massachusetts.",
            "importance": 4,
            "metadata": {},
            "active": True,
        }
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    events = [
        event
        async for event in chat_service.stream_message(
            "Can you change my location? It's Summerville with one o and one m.",
            channel=RexBrainChannel.VOICE,
        )
    ]

    assert events[-1]["memory_changes"]["confirmation_required"] == 1
    confirmed = await confirm_durable_write(
        chat_service,
        {
            "conversation_id": events[-1]["conversation_id"],
            "memory_changes": events[-1]["memory_changes"],
        },
    )
    assert confirmed["memory_changes"]["updated"] == 1
    assert ai_service.messages == []
    assert len(memory_service.long_term_memory) == 1
    assert memory_service.long_term_memory[0]["content"] == (
        "User lives in Somerville, Massachusetts."
    )


@pytest.mark.asyncio
async def test_voice_stream_directly_saves_personal_movie_plan():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    events = [
        event
        async for event in chat_service.stream_message(
            "Today, they released the messes of the universe movie. I'm gonna watch.",
            channel=RexBrainChannel.VOICE,
        )
    ]

    assert events[-1]["memory_changes"]["confirmation_required"] == 1
    assert ai_service.messages == []
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_personal_plan_updates_keep_exact_title_and_single_memory():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    planned_proposed = await chat_service.send_message(
        "They just released Masters of the Universe, and I'm gonna watch it tonight."
    )
    planned = await confirm_durable_write(chat_service, planned_proposed)
    tickets_proposed = await chat_service.send_message(
        "I already bought the tickets.",
        planned["conversation_id"],
    )
    tickets = await confirm_durable_write(chat_service, tickets_proposed)
    canceled_proposed = await chat_service.send_message(
        "I gotta cancel that because my money is tight.",
        planned["conversation_id"],
    )
    canceled = await confirm_durable_write(chat_service, canceled_proposed)

    assert planned["memory_changes"]["created"] == 1
    assert tickets["memory_changes"]["updated"] == 1
    assert canceled["memory_changes"]["updated"] == 1
    assert ai_service.messages == []
    assert len(memory_service.long_term_memory) == 1
    assert memory_service.long_term_memory[0]["content"] == (
        "User canceled the plan to watch Masters of the Universe tonight because money is tight."
    )
    assert memory_service.long_term_memory[0]["metadata"]["topic_fingerprint"] == (
        "event:personal_plan:watch:masters_of_the_universe"
    )


@pytest.mark.asyncio
async def test_delete_saved_tonight_plan_requires_confirmation_and_archives_memory():
    ai_service = FakeAIService(response="Rex normal recall")
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "memory-tonight-plan",
            "memory_type": "event",
            "content": "User plans to watch it tonight.",
            "importance": 4,
            "active": True,
            "metadata": {
                "fact_kind": "personal_plan",
                "topic_fingerprint": "event:personal_plan:watch:it",
            },
        }
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    requested = await chat_service.send_message("Can you delete that tonight plan?")

    assert requested["memory_changes"]["confirmation_required"] == 1
    assert requested["memory_changes"]["write_proposals"][0]["write_kind"] == "delete"
    assert "cannot be undone" in (
        requested["memory_changes"]["write_proposals"][0]["confirmation_text"].lower()
    )
    assert memory_service.long_term_memory[0]["active"] is True
    assert ai_service.messages == []

    confirmed = await confirm_durable_write(chat_service, requested)

    assert "Permanently deleted" in confirmed["response"]
    assert confirmed["memory_changes"]["archived"] == 1
    assert memory_service.long_term_memory == []
    assert ai_service.messages == []

    await chat_service.send_message(
        "What else do you know?",
        requested["conversation_id"],
    )

    assert "saved_knowledge=empty count=0" in ai_service.messages[0]["content"]


@pytest.mark.asyncio
async def test_delete_that_event_resolves_visible_knows_event_memory():
    ai_service = FakeAIService(response="Rex normal recall")
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "memory-visible-event",
            "memory_type": "event",
            "content": "User plans to watch it tonight.",
            "importance": 4,
            "active": True,
            "metadata": {
                "fact_kind": "personal_plan",
                "memory_category": "events",
                "topic_fingerprint": "event:personal_plan:watch:it",
            },
        }
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    requested = await chat_service.send_message("Can you delete that event?")
    confirmed = await confirm_durable_write(chat_service, requested)

    assert requested["memory_changes"]["confirmation_required"] == 1
    assert "User plans to watch it tonight." in requested["memory_changes"]["write_proposals"][0]["confirmation_text"]
    assert confirmed["memory_changes"]["archived"] == 1
    assert memory_service.long_term_memory == []
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_delete_it_resolves_recently_listed_saved_memory():
    ai_service = FakeAIService(response="Rex normal recall")
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "memory-tonight-plan",
            "memory_type": "event",
            "content": "User plans to watch it tonight.",
            "importance": 4,
            "active": True,
            "metadata": {
                "fact_kind": "personal_plan",
                "topic_fingerprint": "event:personal_plan:watch:it",
            },
        }
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )
    conversation_id = await memory_service.create_conversation()
    await memory_service.save_message(
        conversation_id,
        "assistant",
        (
            "Clarity has this saved about you:\n\n"
            'Plus one older saved note: "User plans to watch it tonight" '
            "(from about 2 weeks ago). That's all the durable saved knowledge."
        ),
    )

    requested = await chat_service.send_message(
        "Is it a note or a memory? I see it as a event memory, can you delete it?",
        conversation_id,
    )
    confirmed = await confirm_durable_write(chat_service, requested)

    assert requested["memory_changes"]["confirmation_required"] == 1
    assert "User plans to watch it tonight" in requested["memory_changes"]["write_proposals"][0]["confirmation_text"]
    assert confirmed["memory_changes"]["archived"] == 1
    assert memory_service.long_term_memory == []
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_delete_saved_memory_accepts_get_rid_of_wording():
    ai_service = FakeAIService(response="Rex normal recall")
    memory_service = FakeMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "memory-event-note",
            "memory_type": "event",
            "content": "User has an event note about watching it tonight.",
            "importance": 4,
            "active": True,
            "metadata": {"fact_kind": "personal_plan"},
        }
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    requested = await chat_service.send_message("Can you get rid of that event note?")
    confirmed = await confirm_durable_write(chat_service, requested)

    assert requested["memory_changes"]["confirmation_required"] == 1
    assert confirmed["memory_changes"]["archived"] == 1
    assert memory_service.long_term_memory == []
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_delete_entity_event_requires_confirmation_and_archives_event():
    ai_service = FakeAIService(response="Rex normal recall")
    memory_service = FakeMemoryService()
    memory_service.entity_events.append(
        {
            "id": "event-birthday-note",
            "entity_id": "entity-mom",
            "event_type": "birthday",
            "title": "Mom birthday note",
            "content": "Mom's birthday is June 18.",
            "active": True,
        }
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    requested = await chat_service.send_message("Delete the Mom birthday note")
    confirmed = await confirm_durable_write(chat_service, requested)

    assert requested["memory_changes"]["confirmation_required"] == 1
    assert confirmed["memory_changes"]["archived"] == 1
    assert memory_service.entity_events == []
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_delete_saved_memory_does_not_claim_success_without_backend_confirmation():
    class UnconfirmedDeleteMemoryService(FakeMemoryService):
        async def delete_long_term_memory(self, memory_id):
            return True

    ai_service = FakeAIService(response="Rex normal recall")
    memory_service = UnconfirmedDeleteMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "memory-tonight-plan",
            "memory_type": "event",
            "content": "User plans to watch it tonight.",
            "importance": 4,
            "active": True,
            "metadata": {"fact_kind": "personal_plan"},
        }
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    requested = await chat_service.send_message("Can you delete that tonight plan?")
    confirmed = await confirm_durable_write(chat_service, requested)

    assert "couldn't delete" in confirmed["response"].lower()
    assert "Permanently deleted" not in confirmed["response"]
    assert confirmed["memory_changes"]["archived"] == 0
    assert memory_service.long_term_memory[0]["active"] is True
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_delete_saved_memory_rechecks_active_listing_before_success():
    class StaleActiveDeleteMemoryService(FakeMemoryService):
        async def delete_long_term_memory(self, memory_id):
            return True

    ai_service = FakeAIService(response="Rex normal recall")
    memory_service = StaleActiveDeleteMemoryService()
    memory_service.long_term_memory.append(
        {
            "id": "memory-tonight-plan",
            "memory_type": "event",
            "content": "User plans to watch it tonight.",
            "importance": 4,
            "active": True,
            "metadata": {"fact_kind": "personal_plan"},
        }
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    requested = await chat_service.send_message("Can you delete that tonight plan?")
    confirmed = await confirm_durable_write(chat_service, requested)

    assert "couldn't delete" in confirmed["response"].lower()
    assert "Permanently deleted" not in confirmed["response"]
    assert confirmed["memory_changes"]["archived"] == 0
    assert memory_service.long_term_memory[0]["active"] is True
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_delete_success_claim_without_backend_action_is_blocked():
    ai_service = FakeAIService(response="Done, I deleted it.")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    result = await chat_service.send_message("Can you delete?")

    assert "confirmed backend delete" in result["response"]
    assert "Done, I deleted it" not in result["response"]
    assert result["memory_changes"] is None


@pytest.mark.asyncio
async def test_simple_memory_rejection_does_not_create_durable_memory():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    conversation_id = await memory_service.create_conversation()
    await memory_service.save_message(
        conversation_id,
        "user",
        "My mom's birthday is June 18.",
    )
    await memory_service.save_message(
        conversation_id,
        "assistant",
        "Want me to remember that?",
    )

    rejected = await chat_service.send_message("no don't save that", conversation_id)

    assert rejected["response"] == "No problem. I won't save that."
    assert rejected["memory_changes"]["skipped"] == 1
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_simple_memory_repeated_confirmation_does_not_save_duplicate_memory():
    ai_service = FakeAIService(response="Rex normal follow-up")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    proposed = await chat_service.send_message("My mom's birthday is June 18")
    saved = await confirm_durable_write(chat_service, proposed)
    follow_up = await chat_service.send_message("yes", saved["conversation_id"])

    assert saved["memory_changes"]["created"] == 1
    assert follow_up["response"] == "Rex normal follow-up"
    assert follow_up["memory_changes"] is None
    assert len(memory_service.long_term_memory) == 1


@pytest.mark.asyncio
async def test_simple_memory_repeated_fact_does_not_save_duplicate_memory():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    proposed = await chat_service.send_message("My mom's birthday is on the 18th")
    confirmation = await confirm_durable_write(chat_service, proposed)
    repeated = await chat_service.send_message(
        "My mom's birthday is June 18",
        confirmation["conversation_id"],
    )

    assert repeated["response"] == "I already have that saved."
    assert repeated["memory_changes"]["skipped"] == 1
    assert len(memory_service.long_term_memory) == 1
    assert len(memory_service.entities) == 0


@pytest.mark.asyncio
async def test_relationship_person_save_after_mom_birthday_does_not_reuse_birthday_memory():
    ai_service = FakeAIService(response="Rex follow-up")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    mom_proposed = await chat_service.send_message("My mom's birthday is January 1.")
    mom_saved = await confirm_durable_write(chat_service, mom_proposed)
    conversation_id = mom_saved["conversation_id"]
    assert mom_saved["memory_changes"]["created"] == 1

    friend_proposed = await chat_service.send_message(
        "Remember that my best friend is Pedro.",
        conversation_id,
    )
    confirmed = await confirm_durable_write(chat_service, friend_proposed)

    assert "Saved to Clarity Knows" in confirmed["response"]
    assert confirmed["memory_changes"]["created"] == 1
    assert len(memory_service.long_term_memory) == 2
    assert len(memory_service.entities) == 0
    assert any("Pedro" in memory["content"] for memory in memory_service.long_term_memory)


@pytest.mark.asyncio
async def test_possessive_third_party_birthday_saves_correct_person_label():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    proposed = await chat_service.send_message("Pedro's mom birthday is june 18")
    assert proposed["memory_changes"]["confirmation_required"] == 1
    saved = await confirm_durable_write(chat_service, proposed)

    assert saved["memory_changes"]["created"] == 1
    assert "Pedro" in memory_service.long_term_memory[0]["content"]
    assert "June 18" in memory_service.long_term_memory[0]["content"]
    assert ai_service.generate_calls == 0


@pytest.mark.asyncio
async def test_name_correction_updates_saved_person_card():
    ai_service = FakeAIService(response="Rex follow-up")
    memory_service = FakeMemoryService()
    _seed_pedro_mom_entity(memory_service, display_name="S Mom", normalized_name="s mom")
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    corrected = await chat_service.send_message("The S Mom is actually Pedro's Mom")

    assert corrected["memory_changes"]["updated"] >= 1
    assert "updated saved memory from S Mom to Pedro's Mom" in corrected["response"]
    assert memory_service.entities[0]["display_name"] == "Pedro's Mom"
    assert ai_service.generate_calls == 0


@pytest.mark.asyncio
async def test_change_name_does_not_save_trailing_please():
    ai_service = FakeAIService(response="Rex follow-up")
    memory_service = FakeMemoryService()
    _seed_pedro_mom_entity(memory_service, display_name="S Mom", normalized_name="s mom")
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    corrected = await chat_service.send_message(
        "Can you change S Mom to Pedro's Mom please?",
    )

    assert corrected["memory_changes"]["updated"] >= 1
    assert memory_service.entities[0]["display_name"] == "Pedro's Mom"
    assert ai_service.generate_calls == 0


@pytest.mark.asyncio
async def test_without_please_strips_saved_entity_name():
    ai_service = FakeAIService(response="Rex follow-up")
    memory_service = FakeMemoryService()
    _seed_pedro_mom_entity(
        memory_service,
        display_name="Pedro's Mom please",
        normalized_name="pedro s mom please",
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    corrected = await chat_service.send_message(
        "Yes but without the 'please' haha",
    )

    assert corrected["memory_changes"]["updated"] >= 1
    assert memory_service.entities[0]["display_name"] == "Pedro's Mom"
    assert ai_service.generate_calls == 0


@pytest.mark.asyncio
async def test_confirmed_mom_birthday_rephrase_skips_without_entity_promotion():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    proposed = await chat_service.send_message("My mom's birthday is June 18")
    saved = await confirm_durable_write(chat_service, proposed)
    repeated = await chat_service.send_message(
        "It's not next week, but on the eighteenth, it's my mom's birthday.",
        saved["conversation_id"],
    )

    assert repeated["memory_changes"]["skipped"] == 1
    assert len(memory_service.long_term_memory) == 1
    assert len(memory_service.entities) == 0


@pytest.mark.asyncio
async def test_confirmed_self_facts_stay_flat_without_entity_promotion():
    ai_service = FakeAIService(response="Rex recall follow-up")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    name_proposed = await chat_service.send_message("My name is Pedro Martins.")
    name = await confirm_durable_write(chat_service, name_proposed)
    conversation_id = name["conversation_id"]

    location_proposed = await chat_service.send_message(
        "I live in Somerville.",
        conversation_id,
    )
    location = await confirm_durable_write(chat_service, location_proposed)

    birthday_proposed = await chat_service.send_message(
        "My birthday is June 18.",
        conversation_id,
    )
    birthday = await confirm_durable_write(chat_service, birthday_proposed)

    work_proposed = await chat_service.send_message(
        "I work at Bom Dough.",
        conversation_id,
    )
    work = await confirm_durable_write(chat_service, work_proposed)

    assert name["memory_changes"]["created"] == 1
    assert location["memory_changes"]["created"] == 1
    assert birthday["memory_changes"]["created"] == 1
    assert work["memory_changes"]["created"] == 1
    assert len(memory_service.long_term_memory) == 4
    assert all(memory["active"] is True for memory in memory_service.long_term_memory)
    assert len(memory_service.entities) == 0
    assert all(
        "duplicate_archive_reason" not in (memory.get("metadata") or {})
        for memory in memory_service.long_term_memory
    )

    recall = await chat_service.send_message(
        "What does Clarity know about me?",
        conversation_id,
    )

    assert ai_service.generate_calls == 1
    prompt_text = ai_service.messages[0]["content"]
    assert "User's name is Pedro Martins" in prompt_text
    assert "User lives in Somerville" in prompt_text
    assert "- saved knowledge/person Pedro Martins - self" not in prompt_text
    assert recall["response"] == "Rex recall follow-up"


@pytest.mark.asyncio
async def test_contextual_memory_save_request_saves_recent_birthday_without_card():
    ai_service = FakeAIService(response="Rex normal follow-up")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )
    conversation_id = await memory_service.create_conversation()
    await memory_service.save_message(
        conversation_id,
        "user",
        "I'm thinking about my mom and her birthday. It is on this month.",
    )
    await memory_service.save_message(
        conversation_id,
        "assistant",
        "Nice, when's her birthday exactly?",
    )
    await memory_service.save_message(conversation_id, "user", "On the eighteenth.")
    await memory_service.save_message(
        conversation_id,
        "assistant",
        "June 18th, got it. Want me to remember that?",
    )

    proposed = await chat_service.send_message("yes keep that in memory", conversation_id)
    saved = await confirm_durable_write(chat_service, proposed)

    assert "Saved to Clarity Knows" in saved["response"]
    assert saved["memory_changes"]["created"] == 1
    assert memory_service.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 18."
    )


@pytest.mark.asyncio
async def test_contextual_memory_save_extracts_birthday_date_from_rex_previous_turn():
    ai_service = FakeAIService(response="Rex normal follow-up")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )
    conversation_id = await memory_service.create_conversation()
    await memory_service.save_message(
        conversation_id,
        "user",
        "How about you remember me about my mom's birthday?",
    )
    await memory_service.save_message(
        conversation_id,
        "assistant",
        "Got it, I'll remember your mom's birthday on the 18th. Want a reminder?",
    )

    proposed = await chat_service.send_message("yes keep that in memory", conversation_id)
    saved = await confirm_durable_write(chat_service, proposed)

    assert "Saved to Clarity Knows" in saved["response"]
    assert saved["memory_changes"]["created"] == 1
    assert memory_service.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 18."
    )


@pytest.mark.asyncio
async def test_contextual_memory_reject_request_does_not_save_recent_birthday():
    ai_service = FakeAIService(response="Rex normal follow-up")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )
    conversation_id = await memory_service.create_conversation()
    await memory_service.save_message(
        conversation_id,
        "user",
        "My mom's birthday is June 18.",
    )
    await memory_service.save_message(
        conversation_id,
        "assistant",
        "Want me to remember that?",
    )

    rejected = await chat_service.send_message("no don't save that", conversation_id)

    assert rejected["response"] == "No problem. I won't save that."
    assert rejected["memory_changes"]["skipped"] == 1
    assert memory_service.long_term_memory == []


@pytest.mark.asyncio
async def test_simple_memory_non_confirmation_continues_normal_chat_without_save():
    ai_service = FakeAIService(response="Rex normal follow-up")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    proposed = await chat_service.send_message("My mom's birthday is June 18")
    assert proposed["memory_changes"]["confirmation_required"] == 1
    follow_up = await chat_service.send_message(
        "Why does that matter?",
        proposed["conversation_id"],
    )

    assert "pending save" in follow_up["response"].lower()
    assert follow_up["memory_changes"]["confirmation_required"] == 1
    assert memory_service.long_term_memory == []
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_vague_delete_memory_asks_for_specific_title():
    ai_service = FakeAIService(response="Deleted everything.")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    result = await chat_service.send_message("Can you delete a memory please?")

    assert "exact saved item" in result["response"].casefold()
    assert result["memory_changes"]["archived"] == 0
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_delete_goal_by_starting_as_reference():
    ai_service = FakeAIService(response="Deleted the bad goal.")
    memory_service = FakeMemoryService()
    memory_service.plans.append(
        {
            "id": "plan-junk",
            "title": "Be a goal/commitment",
            "description": "be a goal/commitment",
            "plan_type": "personal",
            "active": True,
        }
    )
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    requested = await chat_service.send_message("Can you delete a memory please?")
    clarified = await chat_service.send_message(
        "The one starting as 'be a goal...'",
        requested["conversation_id"],
    )
    confirmed = await confirm_durable_write(chat_service, clarified)

    assert "exact saved item" in requested["response"].casefold()
    assert clarified["memory_changes"]["confirmation_required"] == 1
    assert confirmed["memory_changes"]["archived"] == 1
    assert memory_service.plans == []
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_hardware_goal_message_creates_two_plans_without_llm():
    ai_service = FakeAIService(response="Confirmed—your next-month goal is set.")
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    result = await chat_service.send_message(
        "Get 32gb-64gb ram and 1tb-2tb storage by next month"
    )

    assert ai_service.generate_calls == 0
    assert result["memory_changes"]["confirmation_required"] == 1
    assert len(memory_service.created_plans) == 0

    confirmed = await confirm_durable_write(chat_service, result)
    assert confirmed["memory_changes"]["created"] == 1
    assert len(memory_service.created_plans) == 1

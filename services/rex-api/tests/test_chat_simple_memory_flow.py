from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from chat_service_fakes import (
    FakeAIService,
    FakeMemoryService,
)
from app.services.chat_service import ChatService
from app.services.file_service import FileService
from app.services.rex_brain_contracts import RexBrainChannel
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

    saved = await chat_service.send_message("My mom's birthday is on the 18th")

    assert saved["response"] == "Got it, your mom's birthday is June 18."
    assert saved["memory_changes"]["created"] == 1
    assert saved["memory_changes"]["confirmation_required"] == 0
    assert saved["memory_changes"]["records"][0]["action"] == "direct_saved"
    assert saved["messages"][-1]["content"] == saved["response"]
    assert ai_service.messages == []
    assert memory_service.long_term_memory[0]["memory_type"] == "fact"
    assert memory_service.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 18."
    )
    assert len(memory_service.entities) == 1
    assert memory_service.entities[0]["display_name"] == "Mom"
    assert memory_service.entities[0]["relationship"] == "mother"
    assert memory_service.entities[0]["metadata"]["attributes"] == {
        "birthday": "June 18",
    }

    await chat_service.send_message(
        "Do you remember my mom's birthday?",
        saved["conversation_id"],
    )

    assert (
        "- fact: User's mom's birthday is June 18."
        not in ai_service.messages[0]["content"]
    )
    assert "- saved knowledge/person Mom - mother" in ai_service.messages[0]["content"]
    assert "birthday: June 18" in ai_service.messages[0]["content"]


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

    saved = await chat_service.send_message(
        "It's not next week, but on the eighteenth, it's my mom's birthday."
    )

    assert saved["response"] == "Got it, your mom's birthday is June 18."
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

    name_turn = await chat_service.send_message("My name is Pedro")
    location_turn = await chat_service.send_message(
        "I live in Somerville",
        name_turn["conversation_id"],
    )

    assert name_turn["response"] == "Got it, your name is Pedro."
    assert name_turn["memory_changes"]["created"] == 1
    assert location_turn["response"] == "Got it, you live in Somerville."
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
    confirmation = await chat_service.send_message(
        "On the eighteenth.",
        first_turn["conversation_id"],
    )

    assert confirmation["response"] == "Got it, your mom's birthday is June 18."
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

    confirmation = await chat_service.send_message("June 18", conversation_id)

    assert confirmation["response"] == "Got it, your mom's birthday is June 18."
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
    assert confirmation_events[1] == {
        "event": "token",
        "token": "Got it, your mom's birthday is June 18.",
    }
    assert (
        confirmation_events[-1]["response"] == "Got it, your mom's birthday is June 18."
    )
    assert confirmation_events[-1]["memory_changes"]["created"] == 1
    assert ai_service.messages == []
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
        not in ai_service.messages[0]["content"]
    )
    assert "- saved knowledge/person Mom - mother" in ai_service.messages[0]["content"]


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

    assert events[-1]["memory_changes"]["updated"] == 1
    assert events[-1]["response"] == (
        "Got it, I updated that: you live in Somerville, Massachusetts."
    )
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

    assert events[-1]["memory_changes"]["created"] == 1
    assert ai_service.messages == []
    assert memory_service.long_term_memory[0]["memory_type"] == "event"
    assert memory_service.long_term_memory[0]["content"] == (
        "User plans to watch Masters of the Universe today."
    )


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

    planned = await chat_service.send_message(
        "They just released Masters of the Universe, and I'm gonna watch it tonight."
    )
    tickets = await chat_service.send_message(
        "I already bought the tickets.",
        planned["conversation_id"],
    )
    canceled = await chat_service.send_message(
        "I gotta cancel that because my money is tight.",
        planned["conversation_id"],
    )

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

    assert "Just to confirm" in requested["response"]
    assert requested["memory_changes"]["confirmation_required"] == 1
    assert memory_service.long_term_memory[0]["active"] is True
    assert ai_service.messages == []

    confirmed = await chat_service.send_message("Yes", requested["conversation_id"])

    assert "removed from active saved memory" in confirmed["response"]
    assert confirmed["memory_changes"]["archived"] == 1
    assert confirmed["memory_changes"]["records"][0]["action"] == "direct_archived"
    assert confirmed["memory_changes"]["records"][0]["metadata"][
        "backend_confirmed"
    ] is True
    assert memory_service.long_term_memory[0]["active"] is False
    assert memory_service.memory_corrections[0]["target_id"] == "memory-tonight-plan"
    assert ai_service.messages == []

    await chat_service.send_message(
        "What else do you know?",
        requested["conversation_id"],
    )

    assert "saved_knowledge=empty count=0" in ai_service.messages[0]["content"]


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
    confirmed = await chat_service.send_message("Yes", conversation_id)

    assert "Just to confirm" in requested["response"]
    assert "User plans to watch it tonight" in requested["response"]
    assert confirmed["memory_changes"]["archived"] == 1
    assert memory_service.long_term_memory[0]["active"] is False
    assert memory_service.memory_corrections[0]["target_id"] == "memory-tonight-plan"
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
    confirmed = await chat_service.send_message("Yes", requested["conversation_id"])

    assert "Just to confirm" in requested["response"]
    assert confirmed["memory_changes"]["archived"] == 1
    assert memory_service.long_term_memory[0]["active"] is False
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
    confirmed = await chat_service.send_message("Yes", requested["conversation_id"])

    assert "Just to confirm" in requested["response"]
    assert confirmed["memory_changes"]["archived"] == 1
    assert confirmed["memory_changes"]["records"][0]["kind"] == "entity_events"
    assert memory_service.entity_events[0]["active"] is False
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_delete_saved_memory_does_not_claim_success_without_backend_confirmation():
    class UnconfirmedDeleteMemoryService(FakeMemoryService):
        async def deactivate_long_term_memory(self, memory_id):
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
    confirmed = await chat_service.send_message("Yes", requested["conversation_id"])

    assert "couldn't confirm" in confirmed["response"]
    assert "removed from active saved memory" not in confirmed["response"]
    assert confirmed["memory_changes"]["archived"] == 0
    assert confirmed["memory_changes"]["records"][0]["action"] == "delete_failed"
    assert confirmed["memory_changes"]["records"][0]["metadata"][
        "backend_confirmed"
    ] is False
    assert memory_service.long_term_memory[0]["active"] is True
    assert memory_service.memory_corrections == []
    assert ai_service.messages == []


@pytest.mark.asyncio
async def test_delete_saved_memory_rechecks_active_listing_before_success():
    class StaleActiveDeleteMemoryService(FakeMemoryService):
        async def deactivate_long_term_memory(self, memory_id):
            return {"id": memory_id, "active": False}

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
    confirmed = await chat_service.send_message("Yes", requested["conversation_id"])

    assert "couldn't confirm" in confirmed["response"]
    assert "removed from active saved memory" not in confirmed["response"]
    assert confirmed["memory_changes"]["archived"] == 0
    assert confirmed["memory_changes"]["records"][0]["action"] == "delete_failed"
    assert memory_service.long_term_memory[0]["active"] is True
    assert memory_service.memory_corrections == []
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

    saved = await chat_service.send_message("My mom's birthday is June 18")
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

    confirmation = await chat_service.send_message("My mom's birthday is on the 18th")
    repeated = await chat_service.send_message(
        "My mom's birthday is June 18",
        confirmation["conversation_id"],
    )

    assert repeated["response"] == "I already have that saved."
    assert repeated["memory_changes"]["skipped"] == 1
    assert repeated["memory_changes"]["records"][0]["action"] == "already_saved"
    assert len(memory_service.long_term_memory) == 1
    assert len(memory_service.entities) == 1


@pytest.mark.asyncio
async def test_person_memory_card_merges_multiple_high_confidence_facts():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    saved = await chat_service.send_message("My mom's birthday is June 18")
    repeated = await chat_service.send_message(
        "It's not next week, but on the eighteenth, it's my mom's birthday.",
        saved["conversation_id"],
    )

    assert repeated["memory_changes"]["skipped"] == 1
    assert len(memory_service.entities) == 1
    assert memory_service.entities[0]["display_name"] == "Mom"
    assert memory_service.entities[0]["metadata"]["attributes"]["birthday"] == (
        "June 18"
    )


@pytest.mark.asyncio
async def test_self_person_card_aggregates_high_confidence_facts_and_archives_duplicates():
    ai_service = FakeAIService()
    memory_service = FakeMemoryService()
    chat_service = ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=_fixed_time_context_service(),
    )

    name = await chat_service.send_message("My name is Pedro Martins.")
    location = await chat_service.send_message(
        "I live in Somerville.",
        name["conversation_id"],
    )
    birthday = await chat_service.send_message(
        "My birthday is June 18.",
        name["conversation_id"],
    )
    work = await chat_service.send_message(
        "I work at Bom Dough.",
        name["conversation_id"],
    )
    await chat_service.send_message(
        "What does Clarity know about me?",
        name["conversation_id"],
    )

    assert [turn["memory_changes"]["created"] for turn in [name, location, birthday, work]] == [
        1,
        1,
        1,
        1,
    ]
    assert len(memory_service.long_term_memory) == 4
    assert all(memory["active"] is False for memory in memory_service.long_term_memory)
    assert len(memory_service.entities) == 1

    person = memory_service.entities[0]
    attributes = person["metadata"]["attributes"]
    source_ids = person["metadata"]["source_memory_ids"]
    assert person["display_name"] == "Pedro Martins"
    assert person["relationship"] == "self"
    assert attributes["full_name"] == "Pedro Martins"
    assert attributes["location"] == "Somerville"
    assert attributes["birthday"] == "June 18"
    assert attributes["workplace"] == "Bom Dough"
    assert set(source_ids) == {memory["id"] for memory in memory_service.long_term_memory}
    assert all(
        memory["metadata"]["duplicate_archive_reason"]
        == "covered_by_self_person_card"
        for memory in memory_service.long_term_memory
    )
    assert "Bank of America" not in person["aliases"]
    assert "- saved knowledge/person Pedro Martins - self" in ai_service.messages[0][
        "content"
    ]
    assert "- fact: User's name is Pedro Martins." not in ai_service.messages[0][
        "content"
    ]


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

    saved = await chat_service.send_message("yes keep that in memory", conversation_id)

    assert saved["response"] == "Got it, your mom's birthday is June 18."
    assert saved["memory_changes"]["created"] == 1
    assert saved["memory_changes"]["records"][0]["action"] == "direct_saved"
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

    saved = await chat_service.send_message("yes keep that in memory", conversation_id)

    assert saved["response"] == "Got it, your mom's birthday is June 18."
    assert saved["memory_changes"]["created"] == 1
    assert saved["memory_changes"]["records"][0]["action"] == "direct_saved"
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

    confirmation = await chat_service.send_message("My mom's birthday is June 18")
    follow_up = await chat_service.send_message(
        "Why does that matter?",
        confirmation["conversation_id"],
    )

    assert follow_up["response"] == "Rex normal follow-up"
    assert follow_up["memory_changes"] is None
    assert memory_service.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 18."
    )
    assert ai_service.messages[-1]["content"] == "Why does that matter?"

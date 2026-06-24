import pytest

from app.services.memory_turn_service import MemoryTurnService
from memory_turn_fakes import FakeMemoryTurnStore


@pytest.mark.asyncio
async def test_memory_turn_service_saves_simple_memory_directly():
    store = FakeMemoryTurnStore()
    service = MemoryTurnService(store)
    user_message = {
        "id": "message-user",
        "conversation_id": "conversation-1",
        "role": "user",
        "content": "My mom's birthday is June 18",
    }
    store.messages.append(user_message)

    result = await service.handle_turn(
        "My mom's birthday is June 18",
        conversation_id="conversation-1",
        user_message=user_message,
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["response"] == "Got it, your mom's birthday is June 18."
    assert result["memory_changes"]["created"] == 1
    assert result["memory_changes"]["confirmation_required"] == 0
    metadata = result["memory_changes"]["records"][0]["metadata"]
    assert metadata["memory_path"] == "direct_save"
    assert metadata["review_required"] is False
    assert store.long_term_memory[0]["content"] == ("User's mom's birthday is June 18.")


@pytest.mark.asyncio
async def test_memory_turn_service_skips_when_memory_already_saved():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User's mom's birthday is June 18.",
            "importance": 5,
            "metadata": {"topic_fingerprint": "fact:birthday:mom"},
            "active": True,
        }
    )
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "My mom's birthday is June 18",
        conversation_id="conversation-1",
        user_message={
            "id": "message-repeat",
            "content": "My mom's birthday is June 18",
        },
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["response"] == "I already have that saved."
    assert result["memory_changes"]["skipped"] == 1
    assert result["memory_changes"]["records"][0]["action"] == "already_saved"
    assert len(store.long_term_memory) == 1


@pytest.mark.asyncio
async def test_memory_turn_service_updates_same_topic_instead_of_duplicating():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User's mom's birthday is June 18.",
            "importance": 5,
            "metadata": {"topic_fingerprint": "fact:birthday:mom"},
            "active": True,
        }
    )
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "My mom's birthday is June 28",
        conversation_id="conversation-1",
        user_message={
            "id": "message-update",
            "content": "My mom's birthday is June 28",
        },
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["memory_changes"]["updated"] == 1
    assert result["memory_changes"]["records"][0]["action"] == "direct_updated"
    assert len(store.long_term_memory) == 1
    assert store.long_term_memory[0]["content"] == ("User's mom's birthday is June 28.")
    assert store.long_term_memory[0]["metadata"]["updated_from_memory_id"] == (
        "memory-existing"
    )


@pytest.mark.asyncio
async def test_memory_turn_service_updates_birthday_without_my_prefix():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User's mom's birthday is June 18.",
            "importance": 5,
            "metadata": {"topic_fingerprint": "fact:birthday:mom"},
            "active": True,
        }
    )
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "No, mom's birthday is June 28",
        conversation_id="conversation-1",
        user_message={
            "id": "message-update",
            "content": "No, mom's birthday is June 28",
        },
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["memory_changes"]["updated"] == 1
    assert len(store.long_term_memory) == 1
    assert store.long_term_memory[0]["content"] == ("User's mom's birthday is June 28.")


@pytest.mark.asyncio
async def test_memory_turn_service_updates_legacy_location_from_voice_correction():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User lives in Summerville, Massachusetts.",
            "importance": 4,
            "metadata": {},
            "active": True,
        }
    )
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "Quick reminder. Can you change my location? "
        "Because you wrote it wrong. It's Summerville with one o and one m.",
        conversation_id="conversation-1",
        user_message={"id": "message-update", "content": "location correction"},
        conversation_history=[],
        time_context={"date": "2026-06-04"},
    )

    assert result is not None
    assert result["response"] == (
        "Got it, I updated that: you live in Somerville, Massachusetts."
    )
    assert result["memory_changes"]["updated"] == 1
    assert len(store.long_term_memory) == 1
    assert store.long_term_memory[0]["content"] == (
        "User lives in Somerville, Massachusetts."
    )
    assert store.long_term_memory[0]["metadata"]["topic_fingerprint"] == (
        "fact:identity:location"
    )


@pytest.mark.asyncio
async def test_memory_turn_service_updates_negative_location_correction():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User lives in Summerville.",
            "importance": 4,
            "metadata": {},
            "active": True,
        }
    )
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "I don't live in Summerville. It's Somerville with one o and one m.",
        conversation_id="conversation-1",
        user_message={"id": "message-update", "content": "location correction"},
        conversation_history=[],
        time_context={"date": "2026-06-04"},
    )

    assert result is not None
    assert result["response"] == "Got it, I updated that: you live in Somerville."
    assert result["memory_changes"]["updated"] == 1
    assert len(store.long_term_memory) == 1
    assert store.long_term_memory[0]["content"] == "User lives in Somerville."
    assert store.long_term_memory[0]["metadata"]["topic_fingerprint"] == (
        "fact:identity:location"
    )


@pytest.mark.asyncio
async def test_memory_turn_service_updates_direct_city_correction():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User lives in Summerville, Massachusetts.",
            "importance": 4,
            "metadata": {},
            "active": True,
        }
    )
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "Change my city to Somerville.",
        conversation_id="conversation-1",
        user_message={"id": "message-update", "content": "city correction"},
        conversation_history=[],
        time_context={"date": "2026-06-13"},
    )

    assert result is not None
    assert result["response"] == (
        "Got it, I updated that: you live in Somerville, Massachusetts."
    )
    assert result["memory_changes"]["updated"] == 1
    assert store.long_term_memory[0]["content"] == (
        "User lives in Somerville, Massachusetts."
    )


@pytest.mark.asyncio
async def test_memory_turn_service_rejects_direct_garbled_city_correction():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User lives in Somerville, Massachusetts.",
            "importance": 4,
            "metadata": {"topic_fingerprint": "fact:identity:location"},
            "active": True,
        }
    )
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "Change my city to Now I see a user leaves and I don't.",
        conversation_id="conversation-1",
        user_message={"id": "message-update", "content": "garbled city correction"},
        conversation_history=[],
        time_context={"date": "2026-06-13"},
    )

    assert result is not None
    assert result["response"].startswith("I couldn't read the city clearly")
    assert result["memory_changes"]["records"][0]["action"] == (
        "clarification_required"
    )
    assert store.long_term_memory[0]["content"] == (
        "User lives in Somerville, Massachusetts."
    )


@pytest.mark.asyncio
async def test_memory_turn_service_rejects_unclear_transcript_city_correction():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User lives in Somerville, Massachusetts.",
            "importance": 4,
            "metadata": {"topic_fingerprint": "fact:identity:location"},
            "active": True,
        }
    )
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "Change my city to transcript unclear.",
        conversation_id="conversation-1",
        user_message={
            "id": "message-update",
            "content": "voice transcript unclear",
        },
        conversation_history=[],
        time_context={"date": "2026-06-13"},
    )

    assert result is not None
    assert result["response"].startswith("I couldn't read the city clearly")
    assert result["memory_changes"]["records"][0]["action"] == (
        "clarification_required"
    )
    assert store.long_term_memory[0]["content"] == (
        "User lives in Somerville, Massachusetts."
    )


@pytest.mark.asyncio
async def test_memory_turn_service_rejects_unclear_transcript_memory_save():
    store = FakeMemoryTurnStore()
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "Please remember that the transcript is unclear.",
        conversation_id="conversation-1",
        user_message={
            "id": "message-unclear",
            "content": "Please remember that the transcript is unclear.",
        },
        conversation_history=[],
        time_context={"date": "2026-06-13"},
    )

    assert result is not None
    assert result["response"].startswith("I couldn't read that clearly")
    assert result["memory_changes"]["records"][0]["action"] == (
        "clarification_required"
    )
    assert store.long_term_memory == []


@pytest.mark.asyncio
async def test_memory_turn_service_archives_duplicate_bad_location_memory():
    store = FakeMemoryTurnStore()
    store.long_term_memory.extend(
        [
            {
                "id": "memory-good",
                "memory_type": "fact",
                "content": "User lives in Summerville, Massachusetts.",
                "importance": 4,
                "metadata": {"topic_fingerprint": "fact:identity:location"},
                "active": True,
            },
            {
                "id": "memory-bad",
                "memory_type": "fact",
                "content": "User lives in Now I see a user leaves and I don't.",
                "importance": 4,
                "metadata": {},
                "active": True,
            },
        ]
    )
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "Change my city to Somerville.",
        conversation_id="conversation-1",
        user_message={"id": "message-update", "content": "city correction"},
        conversation_history=[],
        time_context={"date": "2026-06-13"},
    )

    assert result is not None
    assert result["memory_changes"]["updated"] == 1
    assert result["memory_changes"]["archived"] == 1
    assert store.long_term_memory[0]["content"] == (
        "User lives in Somerville, Massachusetts."
    )
    assert store.long_term_memory[1]["active"] is False
    assert store.long_term_memory[1]["superseded_by"] == "memory-good"


@pytest.mark.asyncio
async def test_memory_turn_service_does_not_claim_failed_update_succeeded():
    store = FakeMemoryTurnStore(fail_update_memory=True)
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User lives in Summerville.",
            "importance": 4,
            "metadata": {},
            "active": True,
        }
    )
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "I don't live in Summerville. It's Somerville with one o and one m.",
        conversation_id="conversation-1",
        user_message={"id": "message-update", "content": "location correction"},
        conversation_history=[],
        time_context={"date": "2026-06-04"},
    )

    assert result is not None
    assert result["response"] == (
        "I understood that correction, but I couldn't update memory just now. "
        "Please try again in a moment."
    )
    assert result["memory_changes"]["records"][0]["action"] == "save_failed"
    assert store.long_term_memory[0]["content"] == "User lives in Summerville."


@pytest.mark.asyncio
async def test_memory_turn_service_does_not_claim_update_when_knows_cannot_see_it():
    store = FakeMemoryTurnStore(hide_updated_memory_from_list=True)
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User lives in Summerville.",
            "importance": 4,
            "metadata": {},
            "active": True,
        }
    )
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "I don't live in Summerville. It's Somerville with one o and one m.",
        conversation_id="conversation-1",
        user_message={"id": "message-update", "content": "location correction"},
        conversation_history=[],
        time_context={"date": "2026-06-04"},
    )

    assert result is not None
    assert result["response"] == (
        "I understood that correction, but I couldn't confirm it is visible "
        "in Knows yet. Please try again in a moment."
    )
    assert result["memory_changes"]["updated"] == 0
    assert result["memory_changes"]["records"][0]["action"] == "save_failed"
    metadata = result["memory_changes"]["records"][0]["metadata"]
    assert metadata["failure_reason"] == "durable_memory_update_not_visible"


@pytest.mark.asyncio
async def test_memory_turn_service_updates_legacy_name_without_fingerprint():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User's name is Pedro.",
            "importance": 5,
            "metadata": {},
            "active": True,
        }
    )
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "My name is Pedro Martins",
        conversation_id="conversation-1",
        user_message={"id": "message-update", "content": "name correction"},
        conversation_history=[],
        time_context={"date": "2026-06-04"},
    )

    assert result is not None
    assert result["memory_changes"]["updated"] == 1
    assert len(store.long_term_memory) == 1
    assert store.long_term_memory[0]["content"] == "User's name is Pedro Martins."
    assert store.long_term_memory[0]["metadata"]["topic_fingerprint"] == (
        "fact:identity:name"
    )


@pytest.mark.asyncio
async def test_memory_turn_service_updates_legacy_preference_without_fingerprint():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "preference",
            "content": "User prefers coffee over tea.",
            "importance": 4,
            "metadata": {},
            "active": True,
        }
    )
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "I prefer tea over coffee.",
        conversation_id="conversation-1",
        user_message={"id": "message-update", "content": "preference correction"},
        conversation_history=[],
        time_context={"date": "2026-06-04"},
    )

    assert result is not None
    assert result["response"] == "Got it, I updated that: you prefer tea over coffee."
    assert result["memory_changes"]["updated"] == 1
    assert len(store.long_term_memory) == 1
    assert store.long_term_memory[0]["content"] == "User prefers tea over coffee."
    assert store.long_term_memory[0]["metadata"]["topic_fingerprint"] == (
        "preference:tea:coffee"
    )


@pytest.mark.asyncio
async def test_memory_turn_service_updates_legacy_movie_plan_without_fingerprint():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "event",
            "content": "User plans to watch Messes Of The Universe movie today.",
            "importance": 3,
            "metadata": {},
            "active": True,
        }
    )
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "Today, they released the masters of the universe movie. I'm gonna watch.",
        conversation_id="conversation-1",
        user_message={"id": "message-update", "content": "movie plan correction"},
        conversation_history=[],
        time_context={"date": "2026-06-04"},
    )

    assert result is not None
    assert result["response"] == (
        "Got it, I updated that: " "you plan to watch Masters of the Universe today."
    )
    assert result["memory_changes"]["updated"] == 1
    assert len(store.long_term_memory) == 1
    assert store.long_term_memory[0]["content"] == (
        "User plans to watch Masters of the Universe today."
    )


@pytest.mark.asyncio
async def test_memory_turn_service_saves_personal_movie_plan_directly():
    store = FakeMemoryTurnStore()
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "Today, they released the messes of the universe movie. I'm gonna watch.",
        conversation_id="conversation-1",
        user_message={"id": "message-plan", "content": "movie plan"},
        conversation_history=[],
        time_context={"date": "2026-06-04"},
    )

    assert result is not None
    assert result["response"] == (
        "Got it, you plan to watch Masters of the Universe today."
    )
    assert result["memory_changes"]["created"] == 1
    assert store.long_term_memory[0]["memory_type"] == "event"
    assert store.long_term_memory[0]["content"] == (
        "User plans to watch Masters of the Universe today."
    )


@pytest.mark.asyncio
async def test_memory_turn_service_saves_specific_preference_directly():
    store = FakeMemoryTurnStore()
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "I prefer tea over coffee.",
        conversation_id="conversation-1",
        user_message={"id": "message-preference", "content": "preference"},
        conversation_history=[],
        time_context={"date": "2026-06-04"},
    )

    assert result is not None
    assert result["response"] == "Got it, you prefer tea over coffee."
    assert result["memory_changes"]["created"] == 1
    assert store.long_term_memory[0]["memory_type"] == "preference"
    assert store.long_term_memory[0]["content"] == "User prefers tea over coffee."
    assert store.long_term_memory[0]["metadata"]["topic_fingerprint"] == (
        "preference:tea:coffee"
    )


@pytest.mark.asyncio
async def test_memory_turn_service_saves_user_device_model_directly():
    store = FakeMemoryTurnStore()
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "It's a Omen 45 l.",
        conversation_id="conversation-1",
        user_message={"id": "message-pc", "content": "It's a Omen 45 l."},
        conversation_history=[],
        time_context={"date": "2026-06-23"},
    )

    assert result is not None
    assert result["response"] == "Got it, you have an Omen 45L."
    assert result["memory_changes"]["created"] == 1
    assert store.long_term_memory[0]["memory_type"] == "fact"
    assert store.long_term_memory[0]["content"] == "User has an Omen 45L."
    assert store.long_term_memory[0]["metadata"]["fact_kind"] == "device"
    assert "topic_fingerprint" not in store.long_term_memory[0]["metadata"]


@pytest.mark.asyncio
async def test_memory_turn_service_does_not_merge_unrelated_device_facts():
    store = FakeMemoryTurnStore()
    service = MemoryTurnService(store)

    first = await service.handle_turn(
        "It's a Omen 45 l.",
        conversation_id="conversation-1",
        user_message={"id": "message-pc", "content": "It's a Omen 45 l."},
        conversation_history=[],
        time_context={"date": "2026-06-23"},
    )
    second = await service.handle_turn(
        "I have an iPhone 16.",
        conversation_id="conversation-1",
        user_message={"id": "message-phone", "content": "I have an iPhone 16."},
        conversation_history=[],
        time_context={"date": "2026-06-23"},
    )

    assert first is not None
    assert second is not None
    assert first["memory_changes"]["created"] == 1
    assert second["memory_changes"]["created"] == 1
    assert [memory["content"] for memory in store.long_term_memory] == [
        "User has an Omen 45L.",
        "User has an iPhone 16.",
    ]


@pytest.mark.asyncio
async def test_memory_turn_service_saves_pc_model_from_confirmation_context():
    store = FakeMemoryTurnStore()
    service = MemoryTurnService(store)
    history = [
        {
            "id": "message-1",
            "conversation_id": "conversation-1",
            "role": "user",
            "content": "It's a Omen 45 l.",
        },
        {
            "id": "message-2",
            "conversation_id": "conversation-1",
            "role": "assistant",
            "content": "Got it--you have an Omen 45L PC. Want me to save that?",
        },
    ]

    result = await service.handle_turn(
        "Yes, please.",
        conversation_id="conversation-1",
        user_message={"id": "message-3", "content": "Yes, please."},
        conversation_history=history,
        time_context={"date": "2026-06-23"},
    )

    assert result is not None
    assert result["response"] == "Got it, you have an Omen 45L PC."
    assert result["memory_changes"]["created"] == 1
    assert store.long_term_memory[0]["content"] == "User has an Omen 45L PC."


@pytest.mark.asyncio
async def test_memory_turn_service_saves_contextual_birthday_answer():
    store = FakeMemoryTurnStore()
    service = MemoryTurnService(store)
    history = [
        {
            "id": "message-1",
            "conversation_id": "conversation-1",
            "role": "user",
            "content": "I'm thinking about my mom and her birthday this month.",
        },
        {
            "id": "message-2",
            "conversation_id": "conversation-1",
            "role": "assistant",
            "content": "When is her birthday exactly?",
        },
    ]
    store.messages.extend(history)

    result = await service.handle_turn(
        "On the eighteenth.",
        conversation_id="conversation-1",
        user_message={"id": "message-3", "content": "On the eighteenth."},
        conversation_history=history,
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["memory_changes"]["created"] == 1
    assert store.long_term_memory[0]["content"] == ("User's mom's birthday is June 18.")


@pytest.mark.asyncio
async def test_memory_turn_service_saves_birthday_from_bare_confirmation():
    store = FakeMemoryTurnStore()
    service = MemoryTurnService(store)
    history = [
        {
            "id": "message-1",
            "conversation_id": "conversation-1",
            "role": "user",
            "content": "Can you save June 18 as my mom's birthday?",
        },
        {
            "id": "message-2",
            "conversation_id": "conversation-1",
            "role": "assistant",
            "content": "Sure, want me to save June 18 as your mom's birthday?",
        },
    ]
    store.messages.extend(history)

    result = await service.handle_turn(
        "Please.",
        conversation_id="conversation-1",
        user_message={"id": "message-3", "content": "Please."},
        conversation_history=history,
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["response"] == "Got it, your mom's birthday is June 18."
    assert result["memory_changes"]["created"] == 1
    assert result["memory_changes"]["records"][0]["action"] == "direct_saved"
    assert store.long_term_memory[0]["content"] == ("User's mom's birthday is June 18.")
    assert store.entities[0]["metadata"]["attributes"]["birthday"] == "June 18"


@pytest.mark.asyncio
async def test_memory_turn_service_updates_city_from_contextual_spelling_reply():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User lives in Summerville, Massachusetts.",
            "importance": 4,
            "metadata": {"topic_fingerprint": "fact:identity:location"},
            "active": True,
        }
    )
    service = MemoryTurnService(store)
    history = [
        {
            "id": "message-1",
            "conversation_id": "conversation-1",
            "role": "user",
            "content": "Can you fix my city name, which you saved wrong?",
        },
        {
            "id": "message-2",
            "conversation_id": "conversation-1",
            "role": "assistant",
            "content": "Sure, what's the correct city? I'll note it.",
        },
    ]

    result = await service.handle_turn(
        "Massachusetts. It's with one m and o instead of u and two m's.",
        conversation_id="conversation-1",
        user_message={
            "id": "message-3",
            "content": (
                "Massachusetts. It's with one m and o instead of u and two m's."
            ),
        },
        conversation_history=history,
        time_context={"date": "2026-06-12"},
    )

    assert result is not None
    assert result["memory_changes"]["updated"] == 1
    assert store.long_term_memory[0]["content"] == (
        "User lives in Somerville, Massachusetts."
    )


@pytest.mark.asyncio
async def test_memory_turn_service_updates_city_from_compressed_voice_spelling_reply():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User lives in Summerville, Massachusetts.",
            "importance": 4,
            "metadata": {"topic_fingerprint": "fact:identity:location"},
            "active": True,
        }
    )
    service = MemoryTurnService(store)
    history = [
        {
            "id": "message-1",
            "conversation_id": "conversation-1",
            "role": "user",
            "content": "Can you actually change the city name from Summerville?",
        },
        {
            "id": "message-2",
            "conversation_id": "conversation-1",
            "role": "assistant",
            "content": "Sure, what's the right city name? I'll update it.",
        },
    ]

    result = await service.handle_turn(
        "OInsteadOfU1M.",
        conversation_id="conversation-1",
        user_message={"id": "message-3", "content": "OInsteadOfU1M."},
        conversation_history=history,
        time_context={"date": "2026-06-12"},
    )

    assert result is not None
    assert result["response"] == (
        "Got it, I updated that: you live in Somerville, Massachusetts."
    )
    assert result["memory_changes"]["updated"] == 1
    assert store.long_term_memory[0]["content"] == (
        "User lives in Somerville, Massachusetts."
    )


@pytest.mark.asyncio
async def test_memory_turn_service_rejects_ambiguous_city_spelling_fragment():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User lives in Summerville, Massachusetts.",
            "importance": 4,
            "metadata": {"topic_fingerprint": "fact:identity:location"},
            "active": True,
        }
    )
    service = MemoryTurnService(store)
    history = [
        {
            "id": "message-1",
            "conversation_id": "conversation-1",
            "role": "user",
            "content": "Can you change my city name from Summerville?",
        },
        {
            "id": "message-2",
            "conversation_id": "conversation-1",
            "role": "assistant",
            "content": "Sure, what's the right city?",
        },
    ]

    result = await service.handle_turn(
        "Two m's",
        conversation_id="conversation-1",
        user_message={"id": "message-3", "content": "Two m's"},
        conversation_history=history,
        time_context={"date": "2026-06-13"},
    )

    assert result is not None
    assert result["response"].startswith("I couldn't read the city clearly")
    assert result["memory_changes"]["records"][0]["action"] == (
        "clarification_required"
    )
    assert store.long_term_memory[0]["content"] == (
        "User lives in Summerville, Massachusetts."
    )


@pytest.mark.asyncio
async def test_memory_turn_service_rejects_garbled_city_voice_transcript():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User lives in Somerville.",
            "importance": 4,
            "metadata": {"topic_fingerprint": "fact:identity:location"},
            "active": True,
        }
    )
    service = MemoryTurnService(store)
    history = [
        {
            "id": "message-1",
            "conversation_id": "conversation-1",
            "role": "user",
            "content": "No, I meant I didn't see Somerville on my memory.",
        },
        {
            "id": "message-2",
            "conversation_id": "conversation-1",
            "role": "assistant",
            "content": "Got it, updating your city to Somerville.",
        },
    ]

    result = await service.handle_turn(
        "Now I see a user leaves and I don't",
        conversation_id="conversation-1",
        user_message={
            "id": "message-3",
            "content": "Now I see a user leaves and I don't",
        },
        conversation_history=history,
        time_context={"date": "2026-06-13"},
    )

    assert result is not None
    assert result["response"].startswith("I couldn't read the city clearly")
    assert store.long_term_memory[0]["content"] == "User lives in Somerville."


@pytest.mark.asyncio
async def test_memory_turn_service_does_not_hijack_mom_old_chat_lookup_after_city_context():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-location",
            "memory_type": "fact",
            "content": "User lives in Somerville.",
            "importance": 4,
            "metadata": {"topic_fingerprint": "fact:identity:location"},
            "active": True,
        }
    )
    service = MemoryTurnService(store)
    history = [
        {
            "id": "message-1",
            "conversation_id": "conversation-1",
            "role": "user",
            "content": "Can you change my city?",
        },
        {
            "id": "message-2",
            "conversation_id": "conversation-1",
            "role": "assistant",
            "content": "Sure, what city should I update it to?",
        },
        {
            "id": "message-3",
            "conversation_id": "conversation-1",
            "role": "user",
            "content": "Somerville",
        },
        {
            "id": "message-4",
            "conversation_id": "conversation-1",
            "role": "assistant",
            "content": "Got it, I updated that: you live in Somerville.",
        },
    ]

    result = await service.handle_turn(
        "Nope, I want you to look into the chats and find any mentions of my mom",
        conversation_id="conversation-1",
        user_message={
            "id": "message-5",
            "content": (
                "Nope, I want you to look into the chats and find any "
                "mentions of my mom"
            ),
        },
        conversation_history=history,
        time_context={"date": "2026-06-13"},
    )

    assert result is None
    assert store.long_term_memory[0]["content"] == "User lives in Somerville."


@pytest.mark.asyncio
async def test_memory_turn_service_does_not_hijack_birthday_statement_after_city_context():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-location",
            "memory_type": "fact",
            "content": "User lives in Somerville.",
            "importance": 4,
            "metadata": {"topic_fingerprint": "fact:identity:location"},
            "active": True,
        }
    )
    service = MemoryTurnService(store)
    history = [
        {
            "id": "message-1",
            "conversation_id": "conversation-1",
            "role": "user",
            "content": "Can you change my city?",
        },
        {
            "id": "message-2",
            "conversation_id": "conversation-1",
            "role": "assistant",
            "content": "Sure, what city should I update it to?",
        },
    ]

    result = await service.handle_turn(
        "I have previous chats where I told you my mom's birthday",
        conversation_id="conversation-1",
        user_message={
            "id": "message-3",
            "content": "I have previous chats where I told you my mom's birthday",
        },
        conversation_history=history,
        time_context={"date": "2026-06-13"},
    )

    assert result is None
    assert store.long_term_memory[0]["content"] == "User lives in Somerville."


@pytest.mark.asyncio
async def test_memory_turn_service_updates_city_from_clean_contextual_reply():
    store = FakeMemoryTurnStore()
    store.long_term_memory.append(
        {
            "id": "memory-existing",
            "memory_type": "fact",
            "content": "User lives in Summerville, Massachusetts.",
            "importance": 4,
            "metadata": {"topic_fingerprint": "fact:identity:location"},
            "active": True,
        }
    )
    service = MemoryTurnService(store)
    history = [
        {
            "id": "message-1",
            "conversation_id": "conversation-1",
            "role": "user",
            "content": "Can you change my city?",
        },
        {
            "id": "message-2",
            "conversation_id": "conversation-1",
            "role": "assistant",
            "content": "Sure, what city should I update it to?",
        },
    ]

    result = await service.handle_turn(
        "Nope, Somerville",
        conversation_id="conversation-1",
        user_message={"id": "message-3", "content": "Nope, Somerville"},
        conversation_history=history,
        time_context={"date": "2026-06-13"},
    )

    assert result is not None
    assert result["memory_changes"]["updated"] == 1
    assert store.long_term_memory[0]["content"] == (
        "User lives in Somerville, Massachusetts."
    )


@pytest.mark.asyncio
async def test_memory_turn_service_returns_none_for_normal_chat():
    store = FakeMemoryTurnStore()
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "Can you help me budget today?",
        conversation_id="conversation-1",
        user_message={"id": "message-1"},
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )

    assert result is None
    assert store.messages == []
    assert store.long_term_memory == []


@pytest.mark.asyncio
async def test_memory_turn_service_reports_save_failure_without_raising():
    store = FakeMemoryTurnStore(fail_save_memory=True)
    service = MemoryTurnService(store)
    user_message = {
        "id": "message-1",
        "conversation_id": "conversation-1",
        "role": "user",
        "content": "My mom's birthday is June 18",
    }

    result = await service.handle_turn(
        "My mom's birthday is June 18",
        conversation_id="conversation-1",
        user_message=user_message,
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["response"] == (
        "I understood that, but I couldn't save it just now. "
        "Please try again in a moment."
    )
    assert result["memory_changes"]["records"][0]["action"] == "save_failed"
    metadata = result["memory_changes"]["records"][0]["metadata"]
    assert metadata["degraded"] is True
    assert metadata["failure_reason"] == "durable_memory_save_failed"
    assert store.long_term_memory == []


@pytest.mark.asyncio
async def test_memory_turn_service_does_not_claim_success_when_save_returns_no_record():
    store = FakeMemoryTurnStore(return_empty_save_memory=True)
    service = MemoryTurnService(store)
    user_message = {
        "id": "message-1",
        "conversation_id": "conversation-1",
        "role": "user",
        "content": "My mom's birthday is June 18",
    }

    result = await service.handle_turn(
        "My mom's birthday is June 18",
        conversation_id="conversation-1",
        user_message=user_message,
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["response"] == (
        "I understood that, but I couldn't save it just now. "
        "Please try again in a moment."
    )
    assert result["memory_changes"]["created"] == 0
    assert result["memory_changes"]["records"][0]["action"] == "save_failed"
    metadata = result["memory_changes"]["records"][0]["metadata"]
    assert metadata["degraded"] is True
    assert metadata["failure_reason"] == "durable_memory_save_missing"
    assert store.long_term_memory == []


@pytest.mark.asyncio
async def test_memory_turn_service_does_not_claim_save_when_knows_cannot_see_it():
    store = FakeMemoryTurnStore(hide_saved_memory_from_list=True)
    service = MemoryTurnService(store)
    user_message = {
        "id": "message-1",
        "conversation_id": "conversation-1",
        "role": "user",
        "content": "My mom's birthday is June 18",
    }

    result = await service.handle_turn(
        "My mom's birthday is June 18",
        conversation_id="conversation-1",
        user_message=user_message,
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["response"] == (
        "I understood that, but I couldn't confirm it is visible in Knows "
        "yet. Please try again in a moment."
    )
    assert result["memory_changes"]["created"] == 0
    assert result["memory_changes"]["records"][0]["action"] == "save_failed"
    metadata = result["memory_changes"]["records"][0]["metadata"]
    assert metadata["failure_reason"] == "durable_memory_save_not_visible"

import pytest

from memory_turn_fakes import FakeMemoryTurnStore
from app.services.memory_turn_service import MemoryTurnService


@pytest.mark.asyncio
async def test_memory_turn_service_requests_simple_memory_confirmation():
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
    assert result["response"] == "So your mom's birthday is June 18, correct?"
    assert result["memory_changes"]["confirmation_required"] == 1
    metadata = result["memory_changes"]["records"][0]["metadata"]
    assert metadata["memory_path"] == "pending_confirmation"
    assert metadata["review_required"] is True
    assert result["assistant_message"]["content"] == result["response"]
    assert "rex_memory_confirmation" not in str(result)
    assert "rex_memory_confirmation" not in store.messages[-1]["content"]
    assert store.memory_confirmations[0]["content"] == (
        "User's mom's birthday is June 18."
    )
    assert store.memory_confirmations[0]["confirmation_message_id"] == "message-1"
    assert store.long_term_memory == []


@pytest.mark.asyncio
async def test_memory_turn_service_reuses_existing_pending_confirmation_for_same_topic():
    store = FakeMemoryTurnStore()
    service = MemoryTurnService(store)
    await store.create_memory_confirmation(
        {
            "conversation_id": "conversation-1",
            "source_message_id": "message-original",
            "memory_type": "fact",
            "content": "User's mom's birthday is June 18.",
            "importance": 5,
            "metadata": {"topic_fingerprint": "fact:birthday:mom"},
        }
    )

    result = await service.handle_turn(
        "My mom's birthday is on the 18th.",
        conversation_id="conversation-1",
        user_message={
            "id": "message-repeat",
            "role": "user",
            "content": "My mom's birthday is on the 18th.",
        },
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["response"] == "So your mom's birthday is June 18, correct?"
    assert result["memory_changes"]["confirmation_required"] == 1
    assert result["memory_changes"]["records"][0]["id"] == "confirmation-1"
    assert len(store.memory_confirmations) == 1
    assert store.long_term_memory == []


@pytest.mark.asyncio
async def test_memory_turn_service_skips_confirmation_when_memory_already_saved():
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
        user_message={"id": "message-repeat", "content": "My mom's birthday is June 18"},
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["response"] == "I already have that saved."
    assert result["memory_changes"]["skipped"] == 1
    assert result["memory_changes"]["records"][0]["action"] == "already_saved"
    assert len(store.memory_confirmations) == 0
    assert len(store.long_term_memory) == 1


@pytest.mark.asyncio
async def test_memory_turn_service_confirms_and_saves_simple_memory():
    store = FakeMemoryTurnStore()
    service = MemoryTurnService(store)
    marked_response = service.memory_intent_service.with_confirmation_marker(
        "So your mom's birthday is June 18, correct?",
        service.memory_intent_service.detect_simple_memory(
            "My mom's birthday is June 18",
            time_context={"date": "2026-06-01"},
        ),
    )
    store.messages.extend(
        [
            {
                "id": "message-1",
                "conversation_id": "conversation-1",
                "role": "user",
                "content": "My mom's birthday is June 18",
            },
            {
                "id": "message-2",
                "conversation_id": "conversation-1",
                "role": "assistant",
                "content": marked_response,
            },
        ]
    )
    user_message = {
        "id": "message-3",
        "conversation_id": "conversation-1",
        "role": "user",
        "content": "yes",
    }
    store.messages.append(user_message)

    result = await service.handle_turn(
        "yes",
        conversation_id="conversation-1",
        user_message=user_message,
        conversation_history=store.messages[:-1],
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["response"] == (
        "Saved. I'll remember that your mom's birthday is June 18."
    )
    assert result["memory_changes"]["created"] == 1
    assert result["memory_changes"]["records"][0]["action"] == "direct_saved"
    metadata = result["memory_changes"]["records"][0]["metadata"]
    assert metadata["memory_path"] == "direct_save"
    assert metadata["review_required"] is False
    assert store.long_term_memory[0]["memory_type"] == "fact"
    assert store.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 18."
    )
    assert store.long_term_memory[0]["metadata"]["memory_path"] == "direct_save"
    assert "rex_memory_confirmation" not in str(result["messages"])


@pytest.mark.asyncio
async def test_memory_turn_service_confirms_explicit_pending_confirmation():
    store = FakeMemoryTurnStore()
    service = MemoryTurnService(store)
    await store.create_memory_confirmation(
        {
            "conversation_id": "conversation-1",
            "source_message_id": "message-original",
            "memory_type": "fact",
            "content": "User's mom's birthday is June 18.",
            "importance": 5,
            "metadata": {"fact_kind": "birthday"},
        }
    )
    user_message = {
        "id": "message-yes",
        "conversation_id": "conversation-1",
        "role": "user",
        "content": "yes",
    }
    store.messages.append(user_message)

    result = await service.handle_turn(
        "yes",
        conversation_id="conversation-1",
        user_message=user_message,
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["memory_changes"]["created"] == 1
    assert store.long_term_memory[0]["source_message_id"] == "message-original"
    assert store.memory_confirmations[0]["status"] == "confirmed"
    assert store.memory_confirmations[0]["applied_memory_id"] == "memory-1"


@pytest.mark.asyncio
async def test_memory_turn_service_confirmation_does_not_duplicate_existing_memory():
    store = FakeMemoryTurnStore()
    service = MemoryTurnService(store)
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
    await store.create_memory_confirmation(
        {
            "conversation_id": "conversation-1",
            "source_message_id": "message-original",
            "memory_type": "fact",
            "content": "User's mom's birthday is June 18.",
            "importance": 5,
            "metadata": {"topic_fingerprint": "fact:birthday:mom"},
        }
    )

    result = await service.handle_turn(
        "yes",
        conversation_id="conversation-1",
        user_message={"id": "message-yes", "content": "yes"},
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["response"] == "I already have that saved."
    assert result["memory_changes"]["records"][0]["action"] == "already_saved"
    assert len(store.long_term_memory) == 1
    assert store.memory_confirmations[0]["status"] == "confirmed"
    assert store.memory_confirmations[0]["applied_memory_id"] == "memory-existing"


@pytest.mark.asyncio
async def test_memory_turn_service_rejects_explicit_pending_confirmation():
    store = FakeMemoryTurnStore()
    service = MemoryTurnService(store)
    await store.create_memory_confirmation(
        {
            "conversation_id": "conversation-1",
            "source_message_id": "message-original",
            "memory_type": "fact",
            "content": "User's mom's birthday is June 18.",
            "importance": 5,
            "metadata": {"fact_kind": "birthday"},
        }
    )
    user_message = {
        "id": "message-no",
        "conversation_id": "conversation-1",
        "role": "user",
        "content": "no",
    }
    store.messages.append(user_message)

    result = await service.handle_turn(
        "no",
        conversation_id="conversation-1",
        user_message=user_message,
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["response"] == "No problem. I won't save that."
    assert result["memory_changes"]["skipped"] == 1
    assert store.long_term_memory == []
    assert store.memory_confirmations[0]["status"] == "rejected"


@pytest.mark.asyncio
async def test_memory_turn_service_marks_explicit_confirmation_failed_on_save_error():
    store = FakeMemoryTurnStore(fail_save_memory=True)
    service = MemoryTurnService(store)
    await store.create_memory_confirmation(
        {
            "conversation_id": "conversation-1",
            "source_message_id": "message-original",
            "memory_type": "fact",
            "content": "User's mom's birthday is June 18.",
            "importance": 5,
            "metadata": {"fact_kind": "birthday"},
        }
    )
    user_message = {
        "id": "message-yes",
        "conversation_id": "conversation-1",
        "role": "user",
        "content": "yes",
    }
    store.messages.append(user_message)

    result = await service.handle_turn(
        "yes",
        conversation_id="conversation-1",
        user_message=user_message,
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["memory_changes"]["records"][0]["action"] == "save_failed"
    metadata = result["memory_changes"]["records"][0]["metadata"]
    assert metadata["degraded"] is True
    assert metadata["operation"] == "save_long_term_memory"
    assert metadata["failure_reason"] == "durable_memory_save_failed"
    assert metadata["user_visible"] is True
    assert store.long_term_memory == []
    assert store.memory_confirmations[0]["status"] == "failed"
    assert store.memory_confirmations[0]["metadata"]["failure_reason"] == (
        "durable_memory_save_failed"
    )


@pytest.mark.asyncio
async def test_memory_turn_service_ignores_unrelated_reply_to_explicit_confirmation():
    store = FakeMemoryTurnStore()
    service = MemoryTurnService(store)
    await store.create_memory_confirmation(
        {
            "conversation_id": "conversation-1",
            "source_message_id": "message-original",
            "memory_type": "fact",
            "content": "User's mom's birthday is June 18.",
            "importance": 5,
            "metadata": {"fact_kind": "birthday"},
        }
    )

    result = await service.handle_turn(
        "Why does that matter?",
        conversation_id="conversation-1",
        user_message={"id": "message-question", "content": "Why does that matter?"},
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )

    assert result is None
    assert store.long_term_memory == []
    assert store.memory_confirmations[0]["status"] == "pending"


@pytest.mark.asyncio
async def test_memory_turn_service_rejects_simple_memory():
    store = FakeMemoryTurnStore()
    service = MemoryTurnService(store)
    marked_response = service.memory_intent_service.with_confirmation_marker(
        "So your mom's birthday is June 18, correct?",
        service.memory_intent_service.detect_simple_memory(
            "My mom's birthday is June 18",
            time_context={"date": "2026-06-01"},
        ),
    )
    store.messages.append(
        {
            "id": "message-1",
            "conversation_id": "conversation-1",
            "role": "assistant",
            "content": marked_response,
        }
    )
    user_message = {
        "id": "message-2",
        "conversation_id": "conversation-1",
        "role": "user",
        "content": "no",
    }
    store.messages.append(user_message)

    result = await service.handle_turn(
        "no",
        conversation_id="conversation-1",
        user_message=user_message,
        conversation_history=store.messages[:-1],
        time_context={"date": "2026-06-01"},
    )

    assert result is not None
    assert result["response"] == "No problem. I won't save that."
    assert result["memory_changes"]["skipped"] == 1
    assert result["memory_changes"]["records"][0]["action"] == "rejected"
    assert store.long_term_memory == []


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
async def test_memory_turn_service_does_not_crash_when_confirmation_storage_fails():
    store = FakeMemoryTurnStore(fail_confirmation_create=True)
    service = MemoryTurnService(store)

    result = await service.handle_turn(
        "My mom's birthday is June 18",
        conversation_id="conversation-1",
        user_message={
            "id": "message-1",
            "role": "user",
            "content": "My mom's birthday is June 18",
        },
        conversation_history=[],
        time_context={"date": "2026-06-01"},
    )

    assert result is None
    assert store.messages == []
    assert store.memory_confirmations == []
    assert store.long_term_memory == []


@pytest.mark.asyncio
async def test_memory_turn_service_reports_save_failure_without_raising():
    store = FakeMemoryTurnStore(fail_save_memory=True)
    service = MemoryTurnService(store)
    marked_response = service.memory_intent_service.with_confirmation_marker(
        "So your mom's birthday is June 18, correct?",
        service.memory_intent_service.detect_simple_memory(
            "My mom's birthday is June 18",
            time_context={"date": "2026-06-01"},
        ),
    )
    store.messages.append(
        {
            "id": "message-1",
            "conversation_id": "conversation-1",
            "role": "assistant",
            "content": marked_response,
        }
    )
    user_message = {
        "id": "message-2",
        "conversation_id": "conversation-1",
        "role": "user",
        "content": "yes",
    }
    store.messages.append(user_message)

    result = await service.handle_turn(
        "yes",
        conversation_id="conversation-1",
        user_message=user_message,
        conversation_history=store.messages[:-1],
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

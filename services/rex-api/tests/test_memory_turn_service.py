import pytest

from app.services.memory_turn_service import MemoryTurnService


class FakeMemoryTurnStore:
    def __init__(self, *, fail_save_memory=False):
        self.fail_save_memory = fail_save_memory
        self.messages = []
        self.long_term_memory = []
        self.memory_confirmations = []
        self.next_message_id = 1
        self.next_memory_id = 1
        self.next_confirmation_id = 1

    async def save_message(self, conversation_id, role, content):
        message = {
            "id": f"message-{self.next_message_id}",
            "conversation_id": conversation_id,
            "role": role,
            "content": content,
            "timestamp": "2026-06-01T12:00:00Z",
        }
        self.next_message_id += 1
        self.messages.append(message)
        return message

    async def get_recent_messages(self, conversation_id, limit=20):
        messages = [
            message
            for message in self.messages
            if message["conversation_id"] == conversation_id
        ]
        return messages[-limit:]

    async def save_long_term_memory(
        self,
        memory_type,
        content,
        source_conversation_id=None,
        source_message_id=None,
        importance=3,
        metadata=None,
    ):
        if self.fail_save_memory:
            raise RuntimeError("memory write failed")
        memory = {
            "id": f"memory-{self.next_memory_id}",
            "memory_type": memory_type,
            "content": content,
            "source_conversation_id": source_conversation_id,
            "source_message_id": source_message_id,
            "importance": importance,
            "metadata": metadata or {},
        }
        self.next_memory_id += 1
        self.long_term_memory.append(memory)
        return memory

    async def create_memory_confirmation(self, confirmation):
        row = {
            "id": f"confirmation-{self.next_confirmation_id}",
            "status": "pending",
            "confirmation_message_id": None,
            **confirmation,
        }
        self.next_confirmation_id += 1
        self.memory_confirmations.append(row)
        return row

    async def get_latest_pending_memory_confirmation(self, conversation_id):
        pending = [
            row
            for row in self.memory_confirmations
            if row.get("conversation_id") == conversation_id
            and row.get("status") == "pending"
        ]
        return pending[-1] if pending else None

    async def update_memory_confirmation(self, confirmation_id, **updates):
        for row in self.memory_confirmations:
            if row["id"] == confirmation_id:
                row.update(updates)
                return row
        return None

    async def confirm_memory_confirmation(
        self,
        confirmation_id,
        *,
        applied_memory_id=None,
        metadata=None,
    ):
        return await self.update_memory_confirmation(
            confirmation_id,
            status="confirmed",
            applied_memory_id=applied_memory_id,
            metadata=metadata,
        )

    async def reject_memory_confirmation(self, confirmation_id, *, metadata=None):
        return await self.update_memory_confirmation(
            confirmation_id,
            status="rejected",
            metadata=metadata,
        )

    async def fail_memory_confirmation(self, confirmation_id, *, metadata=None):
        return await self.update_memory_confirmation(
            confirmation_id,
            status="failed",
            metadata=metadata,
        )


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
    assert result["assistant_message"]["content"] == result["response"]
    assert "rex_memory_confirmation" not in str(result)
    assert "rex_memory_confirmation" not in store.messages[-1]["content"]
    assert store.memory_confirmations[0]["content"] == (
        "User's mom's birthday is June 18."
    )
    assert store.memory_confirmations[0]["confirmation_message_id"] == "message-1"
    assert store.long_term_memory == []


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
    assert store.long_term_memory[0]["memory_type"] == "fact"
    assert store.long_term_memory[0]["content"] == (
        "User's mom's birthday is June 18."
    )
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
    assert store.long_term_memory == []

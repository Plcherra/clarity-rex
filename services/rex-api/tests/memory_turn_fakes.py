class FakeMemoryTurnStore:
    def __init__(
        self,
        *,
        fail_save_memory=False,
        fail_confirmation_create=False,
    ):
        self.fail_save_memory = fail_save_memory
        self.fail_confirmation_create = fail_confirmation_create
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

    async def list_long_term_memory(self, limit=50, memory_type=None, active=None):
        memories = self.long_term_memory
        if memory_type is not None:
            memories = [
                memory
                for memory in memories
                if memory.get("memory_type") == memory_type
            ]
        if active is not None:
            memories = [
                memory
                for memory in memories
                if memory.get("active", True) is active
            ]
        return memories[:limit]

    async def create_memory_confirmation(self, confirmation):
        if self.fail_confirmation_create:
            raise RuntimeError("confirmation write failed")
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

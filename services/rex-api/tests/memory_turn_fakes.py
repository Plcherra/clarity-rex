class FakeMemoryTurnStore:
    def __init__(
        self,
        *,
        fail_save_memory=False,
        fail_update_memory=False,
    ):
        self.fail_save_memory = fail_save_memory
        self.fail_update_memory = fail_update_memory
        self.messages = []
        self.long_term_memory = []
        self.next_message_id = 1
        self.next_memory_id = 1

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

    async def update_long_term_memory(
        self,
        memory_id,
        memory_type=None,
        content=None,
        importance=None,
        active=None,
        superseded_by=None,
        confidence=None,
        correction_group=None,
        metadata=None,
    ):
        if self.fail_update_memory:
            return None
        for memory in self.long_term_memory:
            if memory["id"] != memory_id:
                continue
            if memory_type is not None:
                memory["memory_type"] = memory_type
            if content is not None:
                memory["content"] = content
            if importance is not None:
                memory["importance"] = importance
            if active is not None:
                memory["active"] = active
            if superseded_by is not None:
                memory["superseded_by"] = superseded_by
            if confidence is not None:
                memory["confidence"] = confidence
            if correction_group is not None:
                memory["correction_group"] = correction_group
            if metadata is not None:
                memory["metadata"] = metadata
            return memory
        return None

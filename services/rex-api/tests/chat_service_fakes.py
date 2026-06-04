from app.services.memory_correction_service import CorrectionIntentType


class FakeAIService:
    def __init__(self, response="Rex response", stream_tokens=None):
        self.messages = []
        self.response = response
        self.stream_tokens = stream_tokens or ["Rex ", "stream"]
        self.generate_calls = 0
        self.stream_calls = 0

    async def generate_response(self, messages, **kwargs):
        self.generate_calls += 1
        self.messages = messages
        self.kwargs = kwargs
        return self.response

    async def stream_response(self, messages, **kwargs):
        self.stream_calls += 1
        self.messages = messages
        self.kwargs = kwargs
        for token in self.stream_tokens:
            yield token


class FakeRexBrainObserver:
    def __init__(self):
        self.calls = []

    def log_turn(self, **kwargs):
        self.calls.append(kwargs)
        return {
            "request_id": kwargs["request_id"],
            "status": kwargs["status"],
            "channel": kwargs["channel"].value,
            "layer": kwargs["decision"].layer.value,
            "effective_model_profile": kwargs["model_route"].effective_profile.value,
        }


class FailingRexBrain:
    def plan_turn(self, brain_input):
        raise RuntimeError("brain planning failed")


class FailingAIService:
    async def generate_response(self, messages, **kwargs):
        raise RuntimeError("AI failed")

    async def stream_response(self, messages, **kwargs):
        raise RuntimeError("AI failed")
        yield


class FakeMemoryService:
    def __init__(self):
        self.conversations = set()
        self.messages = []
        self.long_term_memory = []
        self.next_conversation_id = 1
        self.next_message_id = 1
        self.next_memory_id = 1
        self.next_plan_id = 1
        self.next_commitment_id = 1
        self.relevant_memory_queries = []
        self.structured_context_queries = []
        self.structured_context = {}
        self.plans = []
        self.commitments = []
        self.created_plans = []
        self.created_commitments = []

    async def create_conversation(self):
        conversation_id = f"conversation-{self.next_conversation_id}"
        self.next_conversation_id += 1
        self.conversations.add(conversation_id)
        return conversation_id

    async def conversation_exists(self, conversation_id):
        return conversation_id in self.conversations

    async def save_message(self, conversation_id, role, content):
        message = {
            "id": f"message-{self.next_message_id}",
            "conversation_id": conversation_id,
            "role": role,
            "content": content,
            "timestamp": "2026-05-11T00:00:00Z",
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
        memory = {
            "id": f"memory-{self.next_memory_id}",
            "memory_type": memory_type,
            "content": content,
            "source_conversation_id": source_conversation_id,
            "source_message_id": source_message_id,
            "importance": importance,
            "metadata": metadata or {},
            "active": True,
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

    async def get_relevant_memories(self, query, limit=8):
        self.relevant_memory_queries.append({"query": query, "limit": limit})
        return self.long_term_memory[-limit:]

    async def get_structured_memory_context(self, query):
        self.structured_context_queries.append(query)
        return self.structured_context

    async def create_plan(self, payload):
        plan = {
            "id": f"plan-{self.next_plan_id}",
            "status": "active",
            "active": True,
            "created_at": "2026-05-11T00:00:00Z",
            "updated_at": "2026-05-11T00:00:00Z",
            **payload,
        }
        self.next_plan_id += 1
        self.plans.append(plan)
        self.created_plans.append(plan)
        return plan

    async def list_plans(
        self,
        *,
        plan_type=None,
        status=None,
        active=True,
        limit=50,
    ):
        plans = self.plans
        if plan_type is not None:
            plans = [plan for plan in plans if plan.get("plan_type") == plan_type]
        if status is not None:
            plans = [plan for plan in plans if plan.get("status") == status]
        if active is not None:
            plans = [plan for plan in plans if plan.get("active", True) is active]
        return plans[:limit]

    async def update_plan(self, plan_id, **updates):
        for plan in self.plans:
            if plan["id"] == plan_id:
                plan.update(updates)
                plan["updated_at"] = "2026-05-11T00:00:00Z"
                return plan
        return None

    async def list_plan_milestones(
        self,
        *,
        plan_id=None,
        status=None,
        active=True,
        limit=50,
    ):
        return []

    async def create_commitment(self, payload):
        commitment = {
            "id": f"commitment-{self.next_commitment_id}",
            "status": "open",
            "active": True,
            "created_at": "2026-05-11T00:00:00Z",
            "updated_at": "2026-05-11T00:00:00Z",
            **payload,
        }
        self.next_commitment_id += 1
        self.commitments.append(commitment)
        self.created_commitments.append(commitment)
        return commitment

    async def list_commitments(
        self,
        *,
        commitment_type=None,
        milestone_id=None,
        status=None,
        active=True,
        limit=50,
    ):
        commitments = self.commitments
        if commitment_type is not None:
            commitments = [
                commitment
                for commitment in commitments
                if commitment.get("commitment_type") == commitment_type
            ]
        if milestone_id is not None:
            commitments = [
                commitment
                for commitment in commitments
                if commitment.get("milestone_id") == milestone_id
            ]
        if status is not None:
            commitments = [
                commitment
                for commitment in commitments
                if commitment.get("status") == status
            ]
        if active is not None:
            commitments = [
                commitment
                for commitment in commitments
                if commitment.get("active", True) is active
            ]
        return commitments[:limit]

    async def update_commitment(self, commitment_id, **updates):
        for commitment in self.commitments:
            if commitment["id"] == commitment_id:
                commitment.update(updates)
                commitment["updated_at"] = "2026-05-11T00:00:00Z"
                return commitment
        return None


class FakeAccountabilityService:
    def __init__(self, signals=None, should_fail=False):
        self.signals = signals or []
        self.should_fail = should_fail
        self.calls = []

    async def analyze_signals(self, **kwargs):
        self.calls.append(kwargs)
        if self.should_fail:
            raise RuntimeError("accountability failed")
        return self.signals


class FakeMemoryDisciplineService:
    pass


class FakeCorrectionIntent:
    confidence = 0.9
    intent_type = CorrectionIntentType.REPLACE_VALUE
    old_value = "Flowfirst"
    new_value = "FlowForce"
    target_hint = None


class FakeCorrectionReport:
    def __init__(self, payload):
        self.payload = payload

    def as_dict(self):
        return self.payload


class FakeMemoryCorrectionService:
    def __init__(self, payload):
        self.payload = payload
        self.calls = []

    def detect_correction_intent(self, message):
        self.calls.append(("detect", message))
        return FakeCorrectionIntent()

    async def apply_correction(
        self,
        message,
        *,
        source_conversation_id=None,
        source_message_id=None,
    ):
        self.calls.append(
            (
                "apply",
                message,
                source_conversation_id,
                source_message_id,
            )
        )
        return FakeCorrectionReport(self.payload)


class FakeUpload:
    def __init__(self, filename, content):
        self.filename = filename
        self._content = content

    async def read(self):
        return self._content

import asyncio

from app.services.memory_correction_service import CorrectionIntentType


class FakeAIService:
    def __init__(self, response="Rex response", stream_tokens=None):
        self.messages = []
        self.response = response
        self.stream_tokens = stream_tokens or ["Rex ", "stream"]

    async def generate_response(self, messages, **kwargs):
        self.messages = messages
        self.kwargs = kwargs
        return self.response

    async def stream_response(self, messages, **kwargs):
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
        self.relevant_memory_queries = []
        self.structured_context_queries = []
        self.structured_context = {}

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

    async def save_long_term_memory_from_message(self, conversation_id, message):
        content = message["content"]
        if not content.lower().startswith("remember that "):
            return None

        memory = {
            "id": f"memory-{self.next_memory_id}",
            "memory_type": "fact",
            "content": content.removeprefix("Remember that "),
            "source_conversation_id": conversation_id,
            "source_message_id": message["id"],
            "importance": 5,
            "active": True,
        }
        self.next_memory_id += 1
        self.long_term_memory.append(memory)
        return memory

    async def save_long_term_memory(
        self,
        memory_type,
        content,
        source_conversation_id=None,
        source_message_id=None,
        importance=3,
    ):
        memory = {
            "id": f"memory-{self.next_memory_id}",
            "memory_type": memory_type,
            "content": content,
            "source_conversation_id": source_conversation_id,
            "source_message_id": source_message_id,
            "importance": importance,
            "active": True,
        }
        self.next_memory_id += 1
        self.long_term_memory.append(memory)
        return memory

    async def get_relevant_memories(self, query, limit=8):
        self.relevant_memory_queries.append({"query": query, "limit": limit})
        return self.long_term_memory[-limit:]

    async def get_structured_memory_context(self, query):
        self.structured_context_queries.append(query)
        return self.structured_context


class FakeMemoryExtractionService:
    def __init__(self, should_fail=False, result=None):
        self.should_fail = should_fail
        self.result = result or []
        self.calls = []

    async def extract_and_save(
        self,
        conversation_id,
        user_message,
        assistant_message,
        brain_metadata=None,
    ):
        self.calls.append(
            {
                "conversation_id": conversation_id,
                "user_message": user_message,
                "assistant_message": assistant_message,
                "brain_metadata": brain_metadata,
            }
        )
        if self.should_fail:
            raise RuntimeError("extraction failed")
        return self.result


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


class FakeMemoryCandidateService:
    def __init__(self, pending=None, approved=None):
        self.created = []
        self.pending = pending or []
        self.approved = approved or []
        self.rejected = []
        self.updated = []

    async def create_candidate(self, request):
        candidate = {
            "id": f"candidate-{len(self.created) + 1}",
            "candidate_type": request.candidate_type,
            "payload": request.payload,
            "risk_level": request.risk_level,
            "status": "pending",
            "preview": f"{request.candidate_type}: pending memory change",
        }
        self.created.append(candidate)
        return candidate

    async def list_candidates(
        self,
        *,
        status=None,
        source_conversation_id=None,
        limit=20,
        **kwargs,
    ):
        return self.pending[:limit]

    async def approve_candidate(self, candidate_id, request):
        for candidate in self.pending:
            if candidate["id"] == candidate_id:
                approved = {
                    **candidate,
                    "status": "applied",
                    "applied_record_table": "entities",
                    "applied_record_id": "entity-1",
                    "verification": {
                        "passed": True,
                        "message": "Candidate applied and verified.",
                        "remaining_conflicts": [],
                        "applied_record": {
                            "table": "entities",
                            "id": "entity-1",
                        },
                    },
                }
                self.approved.append(approved)
                return approved
        raise AssertionError(f"unknown candidate {candidate_id}")

    async def reject_candidate(self, candidate_id, request):
        for candidate in self.pending:
            if candidate["id"] == candidate_id:
                rejected = {**candidate, "status": "rejected"}
                self.rejected.append(rejected)
                return rejected
        raise AssertionError(f"unknown candidate {candidate_id}")

    async def update_candidate(self, candidate_id, request):
        for index, candidate in enumerate(self.pending):
            if candidate["id"] == candidate_id:
                payload = request.payload or candidate.get("payload") or {}
                updated = {
                    **candidate,
                    "payload": payload,
                    "reason": request.reason,
                    "preview": f"{candidate['candidate_type']}: {payload.get('content') or payload.get('title') or payload.get('text')}",
                }
                self.pending[index] = updated
                self.updated.append(updated)
                return updated
        raise AssertionError(f"unknown candidate {candidate_id}")

    async def bulk_approve_candidates(self, request):
        approved = []
        skipped = []
        for candidate in self.pending:
            if candidate.get("risk_level") == "high" and not request.include_high_risk:
                skipped.append(candidate)
                continue
            approved.append(await self.approve_candidate(candidate["id"], request))
        return {"approved": approved, "rejected": [], "skipped": skipped}

    async def bulk_reject_candidates(self, request):
        rejected = [
            await self.reject_candidate(candidate["id"], request)
            for candidate in self.pending
        ]
        return {"approved": [], "rejected": rejected, "skipped": []}


class DurableFakeMemoryCandidateService(FakeMemoryCandidateService):
    def __init__(self, memory_service, pending=None):
        super().__init__(pending=pending)
        self.memory_service = memory_service

    async def approve_candidate(self, candidate_id, request):
        for candidate in self.pending:
            if candidate["id"] != candidate_id:
                continue

            payload = candidate.get("payload") or {}
            record = await self.memory_service.save_long_term_memory(
                memory_type=payload["memory_type"],
                content=payload["content"],
                source_conversation_id=candidate.get("source_conversation_id"),
                source_message_id=candidate.get("source_message_id"),
                importance=int(payload.get("importance") or 4),
            )
            approved = {
                **candidate,
                "status": "applied",
                "applied_record_table": "long_term_memory",
                "applied_record_id": record["id"],
                "verification": {
                    "passed": True,
                    "message": "Candidate applied and verified.",
                    "applied_record": {
                        "table": "long_term_memory",
                        "id": record["id"],
                    },
                },
            }
            self.approved.append(approved)
            return approved
        raise AssertionError(f"unknown candidate {candidate_id}")


class BlockingMemoryExtractionService:
    def __init__(self):
        self.calls = []
        self.started = asyncio.Event()
        self.release = asyncio.Event()

    async def extract_and_save(
        self,
        conversation_id,
        user_message,
        assistant_message,
        brain_metadata=None,
    ):
        self.calls.append(
            {
                "conversation_id": conversation_id,
                "user_message": user_message,
                "assistant_message": assistant_message,
                "brain_metadata": brain_metadata,
            }
        )
        self.started.set()
        await self.release.wait()
        return []


class FakeUpload:
    def __init__(self, filename, content):
        self.filename = filename
        self._content = content

    async def read(self):
        return self._content

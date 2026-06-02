import pytest

from app.services.chat_context_service import ChatContextService, PROFILE_MEMORY_QUERY


class FakeContextMemoryStore:
    def __init__(
        self,
        *,
        fail_recent_messages=False,
        fail_relevant_memories=False,
        fail_structured_context=False,
    ):
        self.fail_recent_messages = fail_recent_messages
        self.fail_relevant_memories = fail_relevant_memories
        self.fail_structured_context = fail_structured_context
        self.relevant_memory_queries = []
        self.plan_calls = []
        self.milestone_calls = []
        self.commitment_calls = []
        self.messages = [
            {
                "id": "message-1",
                "role": "user",
                "content": "hello",
                "timestamp": "2026-06-01T12:00:00Z",
            }
        ]
        self.plans = [
            {
                "id": "plan-1",
                "plan_type": "finance",
                "title": "Build emergency fund",
                "desired_outcome": "Save $5,000.",
                "priority": 4,
                "status": "active",
                "active": True,
            }
        ]
        self.milestones = [
            {
                "id": "milestone-1",
                "plan_id": "plan-1",
                "title": "Save first $1,000",
                "status": "open",
                "active": True,
            }
        ]
        self.commitments = [
            {
                "id": "commitment-1",
                "plan_id": "plan-1",
                "title": "Review spending weekly",
                "commitment_text": "Review budget every Sunday.",
                "status": "open",
                "active": True,
            }
        ]

    async def get_relevant_memories(self, query, limit=8):
        self.relevant_memory_queries.append({"query": query, "limit": limit})
        if self.fail_relevant_memories:
            raise RuntimeError("relevant memory failed")
        if query == PROFILE_MEMORY_QUERY:
            return [
                {"id": "profile-1", "content": "Pedro lives in New York"},
                {"id": "shared-1", "content": "Duplicate profile fact"},
            ]
        return [
            {"id": "shared-1", "content": "Duplicate profile fact"},
            {"id": "memory-1", "content": "Pedro likes concise answers"},
        ]

    async def get_recent_messages(self, conversation_id, limit=20):
        if self.fail_recent_messages:
            raise RuntimeError("recent messages failed")
        return self.messages[-limit:]

    async def get_structured_memory_context(self, query):
        if self.fail_structured_context:
            raise RuntimeError("structured context failed")
        return {"profile_facts": [{"fact": "timezone is America/New_York"}]}

    async def list_plans(self, **kwargs):
        self.plan_calls.append(kwargs)
        return self.plans

    async def list_plan_milestones(self, **kwargs):
        self.milestone_calls.append(kwargs)
        return self.milestones

    async def list_commitments(self, **kwargs):
        self.commitment_calls.append(kwargs)
        return self.commitments


class FakeAccountabilityService:
    def __init__(self):
        self.calls = []

    async def analyze_signals(self, **kwargs):
        self.calls.append(kwargs)
        return [{"kind": "commitment", "status": "open"}]


@pytest.mark.asyncio
async def test_chat_context_fetches_and_deduplicates_prompt_context():
    store = FakeContextMemoryStore()
    service = ChatContextService(store)

    history, memories, structured_context = await service.fetch_prompt_context(
        message="remember my preferences",
        conversation_id="conversation-1",
    )

    assert history == store.messages
    assert structured_context["profile_facts"][0]["fact"] == (
        "timezone is America/New_York"
    )
    assert [memory["id"] for memory in memories] == [
        "shared-1",
        "memory-1",
        "profile-1",
    ]
    assert store.relevant_memory_queries == [
        {"query": "remember my preferences", "limit": 8},
        {"query": PROFILE_MEMORY_QUERY, "limit": 4},
    ]


@pytest.mark.asyncio
async def test_chat_context_structured_context_failure_is_best_effort():
    service = ChatContextService(
        FakeContextMemoryStore(fail_structured_context=True)
    )

    _, _, structured_context = await service.fetch_prompt_context(
        message="hello",
        conversation_id=None,
    )

    assert structured_context == {}


@pytest.mark.asyncio
async def test_chat_context_adds_active_goal_context_for_goal_progress_questions():
    store = FakeContextMemoryStore()
    service = ChatContextService(store)

    _, _, structured_context = await service.fetch_prompt_context(
        message="How am I doing on my goals?",
        conversation_id=None,
    )

    assert structured_context["profile_facts"][0]["fact"] == (
        "timezone is America/New_York"
    )
    assert structured_context["plans"][0]["title"] == "Build emergency fund"
    assert structured_context["plan_milestones"][0]["title"] == "Save first $1,000"
    assert structured_context["commitments"][0]["title"] == "Review spending weekly"
    assert structured_context["goal_context"] == {
        "source": "active_goal_context",
        "reason": "User asked about goals, progress, plans, or accountability.",
        "active_plan_count": 1,
        "related_milestone_count": 1,
        "related_commitment_count": 1,
    }
    assert store.plan_calls == [
        {"active": True, "status": "active", "limit": 12}
    ]
    assert store.milestone_calls == [{"active": True, "limit": 40}]
    assert store.commitment_calls == [{"active": True, "limit": 40}]


@pytest.mark.asyncio
async def test_chat_context_skips_goal_context_for_unrelated_chat():
    store = FakeContextMemoryStore()
    service = ChatContextService(store)

    _, _, structured_context = await service.fetch_prompt_context(
        message="hello",
        conversation_id=None,
    )

    assert "plans" not in structured_context
    assert store.plan_calls == []
    assert store.milestone_calls == []
    assert store.commitment_calls == []


@pytest.mark.asyncio
async def test_chat_context_goal_context_detects_goal_punctuation():
    store = FakeContextMemoryStore()
    service = ChatContextService(store)

    _, _, structured_context = await service.fetch_prompt_context(
        message="Tell me about my goals?",
        conversation_id=None,
    )

    assert structured_context["plans"][0]["title"] == "Build emergency fund"
    assert store.plan_calls


@pytest.mark.asyncio
async def test_chat_context_relevant_memory_failure_is_best_effort():
    service = ChatContextService(
        FakeContextMemoryStore(fail_relevant_memories=True)
    )

    history, memories, structured_context = await service.fetch_prompt_context(
        message="hello",
        conversation_id="conversation-1",
    )

    assert history[0]["content"] == "hello"
    assert memories == []
    assert structured_context["profile_facts"][0]["fact"] == (
        "timezone is America/New_York"
    )


@pytest.mark.asyncio
async def test_chat_context_recent_message_failure_is_best_effort():
    service = ChatContextService(
        FakeContextMemoryStore(fail_recent_messages=True)
    )

    history, memories, structured_context = await service.fetch_prompt_context(
        message="hello",
        conversation_id="conversation-1",
    )

    assert history == []
    assert [memory["id"] for memory in memories] == [
        "shared-1",
        "memory-1",
        "profile-1",
    ]
    assert structured_context["profile_facts"][0]["fact"] == (
        "timezone is America/New_York"
    )


@pytest.mark.asyncio
async def test_chat_context_accountability_signal_errors_are_best_effort():
    accountability_service = FakeAccountabilityService()
    service = ChatContextService(
        FakeContextMemoryStore(),
        accountability_service=accountability_service,
    )

    signals = await service.accountability_signals(
        message="I need to call mom tomorrow",
        time_context={"date": "2026-06-01"},
        long_term_memory=[{"content": "mom birthday is June 18"}],
        structured_context={"commitments": [{"title": "Call mom"}]},
    )

    assert signals == [{"kind": "commitment", "status": "open"}]
    assert accountability_service.calls[0]["commitments"] == [
        {"title": "Call mom"}
    ]


@pytest.mark.asyncio
async def test_chat_context_goal_context_feeds_accountability_analysis():
    accountability_service = FakeAccountabilityService()
    service = ChatContextService(
        FakeContextMemoryStore(),
        accountability_service=accountability_service,
    )

    _, long_term_memory, structured_context = await service.fetch_prompt_context(
        message="How am I doing on my goals?",
        conversation_id=None,
    )
    signals = await service.accountability_signals(
        message="How am I doing on my goals?",
        time_context={"date": "2026-06-01"},
        long_term_memory=long_term_memory,
        structured_context=structured_context,
    )

    assert signals == [{"kind": "commitment", "status": "open"}]
    assert accountability_service.calls[0]["plans"][0]["title"] == (
        "Build emergency fund"
    )
    assert accountability_service.calls[0]["plan_milestones"][0]["title"] == (
        "Save first $1,000"
    )
    assert accountability_service.calls[0]["commitments"][0]["title"] == (
        "Review spending weekly"
    )


@pytest.mark.asyncio
async def test_chat_context_goal_context_reaches_rex_prompt():
    service = ChatContextService(FakeContextMemoryStore())

    _, long_term_memory, structured_context = await service.fetch_prompt_context(
        message="How am I doing on my goals?",
        conversation_id=None,
    )
    messages = service.build_prompt_messages(
        message="How am I doing on my goals?",
        conversation_id="conversation-1",
        conversation_history=[],
        long_term_memory=long_term_memory,
        structured_context=structured_context,
        accountability_signals=[],
        file_text=None,
        time_context={"date": "2026-06-01"},
        financial_context=None,
    )

    system_prompt = messages[0]["content"]
    assert "Build emergency fund" in system_prompt
    assert "Save first $1,000" in system_prompt
    assert "Review budget every Sunday." in system_prompt

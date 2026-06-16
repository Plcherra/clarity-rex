import logging
import re

import pytest

from app.services.chat_context_service import (
    ChatContextService,
    MEMORY_INVENTORY_QUERY,
    PROFILE_MEMORY_QUERY,
)
from app.services.rex_intent_router import RexIntent, RexIntentDecision


class FakeContextMemoryStore:
    def __init__(
        self,
        *,
        fail_recent_messages=False,
        fail_relevant_memories=False,
        fail_search_messages=False,
        fail_structured_context=False,
    ):
        self.fail_recent_messages = fail_recent_messages
        self.fail_relevant_memories = fail_relevant_memories
        self.fail_search_messages = fail_search_messages
        self.fail_structured_context = fail_structured_context
        self.relevant_memory_queries = []
        self.search_message_queries = []
        self.structured_context_queries = []
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
        self.past_messages = [
            {
                "id": "past-message-1",
                "role": "user",
                "content": "My preferences are concise answers.",
                "timestamp": "2026-06-01T12:00:00Z",
            },
            {
                "id": "past-message-2",
                "role": "user",
                "content": "My mom's birthday is June 18.",
                "timestamp": "2026-06-01T12:00:00Z",
            },
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
        if query in {PROFILE_MEMORY_QUERY, MEMORY_INVENTORY_QUERY}:
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

    async def search_messages(self, query, limit=50, exclude_conversation_id=None):
        self.search_message_queries.append(
            {
                "query": query,
                "limit": limit,
                "exclude_conversation_id": exclude_conversation_id,
            }
        )
        if self.fail_search_messages:
            raise RuntimeError("past chat search failed")
        terms = {
            term.strip("'").removesuffix("'s")
            for term in re.findall(r"[a-z0-9']+", query.lower())
            if len(term.strip("'")) >= 3
        }
        if terms & {"mom", "mother", "mum", "mama"}:
            terms.update({"mom", "mother", "mum", "mama"})
        matches = []
        for message in reversed(self.past_messages):
            if (
                exclude_conversation_id
                and message.get("conversation_id") == exclude_conversation_id
            ):
                continue
            content = str(message.get("content") or "").lower()
            if any(term in content for term in terms):
                matches.append(message)
            if len(matches) >= limit:
                break
        return matches

    async def get_structured_memory_context(self, query):
        self.structured_context_queries.append(query)
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
        "chat-past-message-1",
    ]
    assert store.relevant_memory_queries == [
        {"query": "remember my preferences", "limit": 8},
        {"query": PROFILE_MEMORY_QUERY, "limit": 4},
    ]
    assert store.search_message_queries == [
        {
            "query": "remember my preferences",
            "limit": 50,
            "exclude_conversation_id": None,
        }
    ]


@pytest.mark.asyncio
async def test_chat_context_skips_memory_and_goals_for_casual_intent():
    store = FakeContextMemoryStore()
    service = ChatContextService(store)

    history, memories, structured_context = await service.fetch_prompt_context(
        message="Hey Rex",
        conversation_id="conversation-1",
        intent_decision=RexIntentDecision(RexIntent.CASUAL),
    )

    assert history == store.messages
    assert memories == []
    assert structured_context == {}
    assert store.relevant_memory_queries == []
    assert store.structured_context_queries == []
    assert store.plan_calls == []


@pytest.mark.asyncio
async def test_chat_context_loads_memory_only_for_memory_recall_intent():
    store = FakeContextMemoryStore()
    service = ChatContextService(store)

    _, memories, structured_context = await service.fetch_prompt_context(
        message="Do you remember my mom's birthday?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert [memory["id"] for memory in memories] == [
        "shared-1",
        "memory-1",
        "profile-1",
        "chat-past-message-2",
    ]
    assert structured_context["profile_facts"][0]["fact"] == (
        "timezone is America/New_York"
    )
    assert store.relevant_memory_queries == [
        {"query": "Do you remember my mom's birthday?", "limit": 8},
        {"query": PROFILE_MEMORY_QUERY, "limit": 4},
    ]
    assert store.search_message_queries[:4] == [
        {
            "query": "Do you remember my mom's birthday?",
            "limit": 50,
            "exclude_conversation_id": None,
        },
        {
            "query": "mom mother birthday reminder money send her 10th 18th",
            "limit": 50,
            "exclude_conversation_id": None,
        },
        {
            "query": "mom birthday",
            "limit": 50,
            "exclude_conversation_id": None,
        },
        {
            "query": "send her money birthday",
            "limit": 50,
            "exclude_conversation_id": None,
        },
    ]
    assert {
        "query": "mother birthday",
        "limit": 50,
        "exclude_conversation_id": None,
    } in (store.search_message_queries)
    assert {"query": "mom", "limit": 50, "exclude_conversation_id": None} in (
        store.search_message_queries
    )
    assert store.plan_calls == []


@pytest.mark.asyncio
async def test_chat_context_uses_inventory_query_for_broad_memory_recall():
    store = FakeContextMemoryStore()
    service = ChatContextService(store)

    _, memories, structured_context = await service.fetch_prompt_context(
        message="What do you know?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert "profile_facts" in structured_context
    assert [memory["id"] for memory in memories] == [
        "profile-1",
        "shared-1",
        "chat-past-message-2",
        "chat-past-message-1",
    ]
    assert store.relevant_memory_queries == [
        {"query": MEMORY_INVENTORY_QUERY, "limit": 8},
    ]
    assert store.search_message_queries == [
        {
            "query": MEMORY_INVENTORY_QUERY,
            "limit": 50,
            "exclude_conversation_id": None,
        }
    ]


@pytest.mark.asyncio
async def test_chat_context_uses_inventory_query_for_about_me_recall():
    store = FakeContextMemoryStore()
    service = ChatContextService(store)

    _, memories, structured_context = await service.fetch_prompt_context(
        message="What do you know about me?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert "profile_facts" in structured_context
    assert [memory["id"] for memory in memories] == [
        "profile-1",
        "shared-1",
        "chat-past-message-2",
        "chat-past-message-1",
    ]
    assert store.relevant_memory_queries == [
        {"query": MEMORY_INVENTORY_QUERY, "limit": 8},
    ]


@pytest.mark.asyncio
async def test_chat_context_keeps_specific_person_memory_queries_targeted():
    store = FakeContextMemoryStore()
    service = ChatContextService(store)

    _, memories, _ = await service.fetch_prompt_context(
        message="Do you know anything about my mom?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert any(memory["id"] == "chat-past-message-2" for memory in memories)
    assert store.relevant_memory_queries[0] == {
        "query": "Do you know anything about my mom?",
        "limit": 8,
    }
    assert store.search_message_queries[0]["query"] == (
        "Do you know anything about my mom?"
    )
    assert store.search_message_queries[1]["query"] == (
        "mom mother birthday reminder money send her 10th 18th"
    )


@pytest.mark.asyncio
async def test_chat_context_falls_back_to_subject_search_when_broad_terms_fill_limit():
    store = FakeContextMemoryStore()
    store.past_messages = [
        {
            "id": "noise-1",
            "role": "user",
            "content": "I know this is unrelated.",
            "timestamp": "2026-06-12T12:04:00Z",
        },
        {
            "id": "noise-2",
            "role": "user",
            "content": "Anything else we should test?",
            "timestamp": "2026-06-12T12:03:00Z",
        },
        {
            "id": "noise-3",
            "role": "user",
            "content": "I know my finance dashboard needs polish.",
            "timestamp": "2026-06-12T12:02:00Z",
        },
        {
            "id": "noise-4",
            "role": "user",
            "content": "Anything about the app UI?",
            "timestamp": "2026-06-12T12:01:00Z",
        },
        {
            "id": "mom-1",
            "role": "user",
            "content": "My mom's birthday is on the 18th.",
            "timestamp": "2026-06-11T12:00:00Z",
        },
    ]
    service = ChatContextService(store)

    _, memories, _ = await service.fetch_prompt_context(
        message="Do you know anything about my mom?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert any(memory["id"] == "chat-mom-1" for memory in memories)
    assert len(store.search_message_queries) >= 4
    assert store.search_message_queries[1]["query"] == (
        "mom mother birthday reminder money send her 10th 18th"
    )


@pytest.mark.asyncio
async def test_chat_context_uses_recent_subject_for_old_chat_followup():
    store = FakeContextMemoryStore()
    store.messages = [
        {
            "id": "message-1",
            "role": "user",
            "content": "Do you know anything about my mom?",
            "timestamp": "2026-06-12T12:00:00Z",
        },
        {
            "id": "message-2",
            "role": "assistant",
            "content": "I do not have anything saved about your mom.",
            "timestamp": "2026-06-12T12:00:10Z",
        },
    ]
    service = ChatContextService(store)

    _, memories, _ = await service.fetch_prompt_context(
        message="Can you check the old chats?",
        conversation_id="conversation-1",
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert any(memory["id"] == "chat-past-message-2" for memory in memories)
    assert store.search_message_queries[:4] == [
        {
            "query": (
                "Do you know anything about my mom? Can you check the old chats?"
            ),
            "limit": 50,
            "exclude_conversation_id": None,
        },
        {
            "query": "mom mother birthday reminder money send her 10th 18th",
            "limit": 50,
            "exclude_conversation_id": None,
        },
        {
            "query": "mom birthday",
            "limit": 50,
            "exclude_conversation_id": None,
        },
        {
            "query": "send her money birthday",
            "limit": 50,
            "exclude_conversation_id": None,
        },
    ]
    assert {
        "query": "mom",
        "limit": 50,
        "exclude_conversation_id": None,
    } in store.search_message_queries


@pytest.mark.asyncio
async def test_chat_context_searches_current_conversation_beyond_recent_window():
    store = FakeContextMemoryStore()
    store.messages = [
        {
            "id": "same-conversation-mom",
            "conversation_id": "conversation-1",
            "role": "user",
            "content": "My mom's birthday is June 18.",
            "timestamp": "2026-06-01T12:00:00Z",
        },
        *[
            {
                "id": f"filler-{index}",
                "conversation_id": "conversation-1",
                "role": "user" if index % 2 == 0 else "assistant",
                "content": f"Filler message {index}",
                "timestamp": f"2026-06-01T12:{index:02d}:00Z",
            }
            for index in range(30)
        ],
    ]
    store.past_messages = list(store.messages)
    service = ChatContextService(store)

    history, memories, _ = await service.fetch_prompt_context(
        message="Do you know anything about my mom?",
        conversation_id="conversation-1",
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert all(message["id"] != "same-conversation-mom" for message in history)
    assert any(memory["id"] == "chat-same-conversation-mom" for memory in memories)
    assert store.search_message_queries[0] == {
        "query": "Do you know anything about my mom?",
        "limit": 50,
        "exclude_conversation_id": None,
    }


@pytest.mark.asyncio
async def test_chat_context_loads_goals_without_long_term_memory_for_goal_intent():
    store = FakeContextMemoryStore()
    service = ChatContextService(store)

    _, memories, structured_context = await service.fetch_prompt_context(
        message="How am I doing on my goals?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.GOAL_OR_COMMITMENT),
    )

    assert memories == []
    assert "profile_facts" not in structured_context
    assert structured_context["plans"][0]["title"] == "Build emergency fund"
    assert store.relevant_memory_queries == []
    assert store.search_message_queries == []
    assert store.structured_context_queries == []
    assert store.plan_calls


@pytest.mark.asyncio
async def test_chat_context_skips_memory_and_goals_for_finance_intent():
    store = FakeContextMemoryStore()
    service = ChatContextService(store)

    history, memories, structured_context = await service.fetch_prompt_context(
        message="How much did I spend this week?",
        conversation_id="conversation-1",
        intent_decision=RexIntentDecision(RexIntent.FINANCE),
    )

    assert history == store.messages
    assert memories == []
    assert structured_context == {}
    assert store.relevant_memory_queries == []
    assert store.search_message_queries == []
    assert store.structured_context_queries == []
    assert store.plan_calls == []


@pytest.mark.asyncio
async def test_chat_context_logs_context_fetch_timings(caplog):
    store = FakeContextMemoryStore()
    service = ChatContextService(store)
    caplog.set_level(logging.INFO, logger="rex.context")

    await service.fetch_prompt_context(
        message="Hey Rex",
        conversation_id="conversation-1",
        intent_decision=RexIntentDecision(RexIntent.CASUAL),
    )

    rendered_logs = "\n".join(record.getMessage() for record in caplog.records)
    assert "rex_context_fetch" in rendered_logs
    assert '"intent": "casual"' in rendered_logs
    assert '"long_term_memory": false' in rendered_logs
    assert '"structured_memory": false' in rendered_logs
    assert '"timings_ms"' in rendered_logs


@pytest.mark.asyncio
async def test_chat_context_structured_context_failure_is_best_effort():
    service = ChatContextService(FakeContextMemoryStore(fail_structured_context=True))

    _, _, structured_context = await service.fetch_prompt_context(
        message="hello",
        conversation_id=None,
    )

    memory_status = structured_context["memory_status"]
    assert memory_status["state"] == "degraded"
    assert memory_status["failures"] == [
        {
            "source": "structured_memory",
            "message": "structured context failed",
        }
    ]


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
    assert store.plan_calls == [{"active": True, "status": "active", "limit": 12}]
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
    service = ChatContextService(FakeContextMemoryStore(fail_relevant_memories=True))

    history, memories, structured_context = await service.fetch_prompt_context(
        message="hello",
        conversation_id="conversation-1",
    )

    assert history[0]["content"] == "hello"
    assert memories == []
    assert structured_context["profile_facts"][0]["fact"] == (
        "timezone is America/New_York"
    )
    memory_status = structured_context["memory_status"]
    assert memory_status["state"] == "degraded"
    assert memory_status["failures"] == [
        {"source": "long_term_memory", "message": "relevant memory failed"},
        {"source": "profile_memory", "message": "relevant memory failed"},
    ]


@pytest.mark.asyncio
async def test_chat_context_recent_message_failure_is_best_effort():
    service = ChatContextService(FakeContextMemoryStore(fail_recent_messages=True))

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
    memory_status = structured_context["memory_status"]
    assert memory_status["state"] == "degraded"
    assert memory_status["failures"] == [
        {"source": "recent_messages", "message": "recent messages failed"}
    ]


@pytest.mark.asyncio
async def test_chat_context_past_chat_failure_is_degraded_not_empty_truth():
    service = ChatContextService(FakeContextMemoryStore(fail_search_messages=True))

    _, memories, structured_context = await service.fetch_prompt_context(
        message="Do you know anything about my mom?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert [memory["id"] for memory in memories] == [
        "shared-1",
        "memory-1",
        "profile-1",
    ]
    memory_status = structured_context["memory_status"]
    assert memory_status["state"] == "degraded"
    assert memory_status["failures"] == [
        {"source": "past_chat_memory", "message": "past chat search failed"}
    ]


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
    assert accountability_service.calls[0]["commitments"] == [{"title": "Call mom"}]


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

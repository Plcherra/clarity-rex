import logging
import re

import pytest

from app.services.chat_context_service import (
    ChatContextService,
    MEMORY_INVENTORY_QUERY,
    PROFILE_MEMORY_QUERY,
)
from app.services.chat_search_ranking import ChatSearchRanking
from app.services.rex_intent_router import RexIntent, RexIntentDecision


class FakeContextMemoryStore:
    def __init__(
        self,
        *,
        fail_recent_messages=False,
        fail_relevant_memories=False,
        fail_search_messages=False,
        force_empty_search_messages=False,
        fail_structured_context=False,
    ):
        self.fail_recent_messages = fail_recent_messages
        self.fail_relevant_memories = fail_relevant_memories
        self.fail_search_messages = fail_search_messages
        self.force_empty_search_messages = force_empty_search_messages
        self.fail_structured_context = fail_structured_context
        self.relevant_memory_queries = []
        self.search_message_queries = []
        self.structured_context_queries = []
        self.plan_calls = []
        self.milestone_calls = []
        self.commitment_calls = []
        self.chat_search_ranking = ChatSearchRanking()
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

    async def get_conversation_messages(self, conversation_id, limit=100):
        messages = [
            message
            for message in self.past_messages
            if message.get("conversation_id") == conversation_id
        ]
        if not messages and conversation_id == "conversation-1":
            messages = [
                message
                for message in self.messages
                if message.get("conversation_id") == conversation_id
            ]
        return messages[-limit:]

    async def search_messages(
        self,
        query,
        limit=50,
        exclude_conversation_id=None,
        offset=0,
    ):
        query_log = {
            "query": query,
            "limit": limit,
            "exclude_conversation_id": exclude_conversation_id,
        }
        if offset:
            query_log["offset"] = offset
        self.search_message_queries.append(query_log)
        if self.fail_search_messages:
            raise RuntimeError("past chat search failed")
        if self.force_empty_search_messages:
            return []
        raw_terms = {
            term.strip("'").removesuffix("'s")
            for term in re.findall(r"[a-z0-9']+", query.lower())
            if len(term.strip("'")) >= 3
        }
        terms = set(self.chat_search_ranking.expand_terms(query, max_terms=20))
        terms.update(raw_terms)
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
        return matches[offset : offset + limit]

    async def list_messages(
        self,
        limit=200,
        offset=0,
        exclude_conversation_id=None,
    ):
        matches = []
        for message in reversed(self.past_messages):
            if (
                exclude_conversation_id
                and message.get("conversation_id") == exclude_conversation_id
            ):
                continue
            matches.append(message)
        return matches[offset : offset + limit]

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
    ]
    assert "chat_search_results" not in structured_context
    assert store.search_message_queries == []
    assert store.relevant_memory_queries == [
        {"query": "remember my preferences", "limit": 8},
        {"query": PROFILE_MEMORY_QUERY, "limit": 4},
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
    assert all(not memory["id"].startswith("chat-") for memory in memories)
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
    ]
    result_ids = [item["id"] for item in structured_context["chat_search_results"]]
    assert "chat-past-message-2" in result_ids
    assert structured_context["profile_facts"][0]["fact"] == (
        "timezone is America/New_York"
    )
    assert store.relevant_memory_queries == [
        {"query": "Do you remember my mom's birthday?", "limit": 8},
        {"query": PROFILE_MEMORY_QUERY, "limit": 4},
    ]
    assert store.search_message_queries[:2] == [
        {
            "query": "Do you remember my mom's birthday?",
            "limit": 200,
            "exclude_conversation_id": None,
        },
        {
            "query": "mom mother mum mama birthday birthdays birthdate date event",
            "limit": 200,
            "exclude_conversation_id": None,
        },
    ]
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
    ]
    assert [item["id"] for item in structured_context["chat_search_results"]] == [
        "chat-past-message-2",
        "chat-past-message-1",
    ]
    assert store.relevant_memory_queries == [
        {"query": MEMORY_INVENTORY_QUERY, "limit": 8},
    ]
    assert store.search_message_queries == [
        {
            "query": MEMORY_INVENTORY_QUERY,
            "limit": 200,
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
    ]
    assert [item["id"] for item in structured_context["chat_search_results"]] == [
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

    _, memories, structured_context = await service.fetch_prompt_context(
        message="Do you know anything about my mom?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert all(not memory["id"].startswith("chat-") for memory in memories)
    assert any(
        item["id"] == "chat-past-message-2"
        for item in structured_context["chat_search_results"]
    )
    assert store.relevant_memory_queries[0] == {
        "query": "Do you know anything about my mom?",
        "limit": 8,
    }
    assert store.search_message_queries[0]["query"] == (
        "Do you know anything about my mom?"
    )
    assert store.search_message_queries[1]["query"] == "mom mother mum mama"


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

    _, memories, structured_context = await service.fetch_prompt_context(
        message="Do you know anything about my mom?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert all(not memory["id"].startswith("chat-") for memory in memories)
    assert any(
        item["id"] == "chat-mom-1"
        for item in structured_context["chat_search_results"]
    )
    assert len(store.search_message_queries) >= 2
    assert store.search_message_queries[1]["query"] == "mom mother mum mama"


@pytest.mark.asyncio
async def test_chat_context_ignores_old_failed_search_replies_as_chat_results():
    store = FakeContextMemoryStore()
    store.past_messages = [
        {
            "id": "real-fact",
            "role": "user",
            "content": "It's not next week, but on the eighteenth, it's my mom's birthday.",
            "timestamp": "2026-06-12T18:48:00Z",
        },
        {
            "id": "search-request",
            "role": "user",
            "content": "Can you search into the old chats?",
            "timestamp": "2026-06-12T19:04:00Z",
        },
        {
            "id": "failed-rex-reply",
            "role": "assistant",
            "content": (
                "I double-checked the old chats, but nothing about your mom's "
                "birthday came up."
            ),
            "timestamp": "2026-06-12T19:05:00Z",
        },
    ]
    service = ChatContextService(store)

    _, memories, structured_context = await service.fetch_prompt_context(
        message="Do you know anything about my mom?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert all(not memory["id"].startswith("chat-") for memory in memories)
    result_ids = [item["id"] for item in structured_context["chat_search_results"]]
    assert "chat-real-fact" in result_ids
    assert "chat-failed-rex-reply" not in result_ids
    assert "chat-search-request" not in result_ids


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

    _, memories, structured_context = await service.fetch_prompt_context(
        message="Can you check the old chats?",
        conversation_id="conversation-1",
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert all(not memory["id"].startswith("chat-") for memory in memories)
    assert any(
        item["id"] == "chat-past-message-2"
        for item in structured_context["chat_search_results"]
    )
    assert store.search_message_queries[:3] == [
        {
            "query": (
                "Do you know anything about my mom? Can you check the old chats?"
            ),
            "limit": 200,
            "exclude_conversation_id": None,
        },
        {
            "query": "mom mother mum mama",
            "limit": 200,
            "exclude_conversation_id": None,
        },
        {"query": "mom", "limit": 200, "exclude_conversation_id": None},
    ]
    assert {"query": "mom", "limit": 200, "exclude_conversation_id": None} in (
        store.search_message_queries
    )


@pytest.mark.asyncio
async def test_chat_context_uses_recent_subject_for_short_chat_followup():
    store = FakeContextMemoryStore()
    store.messages = [
        {
            "id": "message-1",
            "role": "user",
            "content": "Right. Do you know anything about my mom?",
            "timestamp": "2026-06-12T12:00:00Z",
        },
        {
            "id": "message-2",
            "role": "assistant",
            "content": "I do not have anything saved about your mom.",
            "timestamp": "2026-06-12T12:00:10Z",
        },
    ]
    store.past_messages = [
        {
            "id": "real-fact",
            "role": "user",
            "content": (
                "It's not next week, but on the eighteenth, it's my mom's "
                "birthday."
            ),
            "timestamp": "2026-06-12T18:48:00Z",
        },
        {
            "id": "failed-rex-reply",
            "role": "assistant",
            "content": "I checked the chats-no mentions of your mom there.",
            "timestamp": "2026-06-12T19:05:00Z",
        },
    ]
    service = ChatContextService(store)

    _, memories, structured_context = await service.fetch_prompt_context(
        message="The chat.",
        conversation_id="conversation-1",
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert all(not memory["id"].startswith("chat-") for memory in memories)
    assert any(
        item["id"] == "chat-real-fact"
        for item in structured_context["chat_search_results"]
    )
    assert store.search_message_queries[0] == {
        "query": "Right. Do you know anything about my mom? The chat.",
        "limit": 200,
        "exclude_conversation_id": None,
    }
    assert {"query": "mom", "limit": 200, "exclude_conversation_id": None} in (
        store.search_message_queries
    )


@pytest.mark.asyncio
async def test_chat_context_searches_past_recent_failed_chat_noise():
    store = FakeContextMemoryStore()
    store.past_messages = [
        {
            "id": "real-fact",
            "role": "user",
            "content": (
                "It's not next week, but on the eighteenth, it's my mom's "
                "birthday."
            ),
            "timestamp": "2026-06-12T18:48:00Z",
        },
        *[
            {
                "id": f"failed-rex-reply-{index}",
                "role": "assistant",
                "content": (
                    "I checked the chats, but no mentions of your mom came up."
                ),
                "timestamp": f"2026-06-12T19:{index:02d}:00Z",
            }
            for index in range(60)
        ],
    ]
    service = ChatContextService(store)

    _, memories, structured_context = await service.fetch_prompt_context(
        message="Do you know anything about my mom?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert all(not memory["id"].startswith("chat-") for memory in memories)
    result_ids = [item["id"] for item in structured_context["chat_search_results"]]
    assert "chat-real-fact" in result_ids
    assert not any("failed-rex-reply" in item for item in result_ids)
    assert store.search_message_queries[0]["limit"] == 200


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("message", "past_content", "expected_text"),
    [
        (
            "What did I say about Lara?",
            "Lara is the friend who recommended the Somerville coffee place.",
            "Lara is the friend",
        ),
        (
            "Search chats for Somerville.",
            "I moved to Somerville because it is closer to work.",
            "moved to Somerville",
        ),
        (
            "Do you remember anything about my notebook preference?",
            "I prefer blue notebooks for planning.",
            "blue notebooks",
        ),
        (
            "Have we talked about my immigration plan?",
            "My immigration plan depends on the EAD renewal timing.",
            "EAD renewal",
        ),
        (
            "What did I tell you about Bom Dough payroll?",
            "Bom Dough payroll usually lands every Friday morning.",
            "payroll usually lands",
        ),
    ],
)
async def test_chat_context_searches_generic_old_chat_subjects(
    message,
    past_content,
    expected_text,
):
    store = FakeContextMemoryStore()
    store.past_messages = [
        {
            "id": "generic-match",
            "role": "user",
            "content": past_content,
            "timestamp": "2026-06-10T12:00:00Z",
        }
    ]
    service = ChatContextService(store)

    _, memories, structured_context = await service.fetch_prompt_context(
        message=message,
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert all(not memory["id"].startswith("chat-") for memory in memories)
    results = structured_context["chat_search_results"]
    assert any(expected_text in item["content"] for item in results)
    status = structured_context["memory_status"]["source_statuses"][0]
    assert status["source"] == "chat_search"
    assert status["attempted"] is True
    assert status["succeeded"] is True
    assert status["result_count"] == 1
    assert status["raw_match_count"] == 1
    assert status["scanned_messages"] >= 1
    assert status["partial"] is False


@pytest.mark.asyncio
async def test_chat_context_paginates_old_chat_search_beyond_first_page():
    store = FakeContextMemoryStore()
    store.past_messages = [
        {
            "id": "lara-real-fact",
            "role": "user",
            "content": "Lara is my friend from the bakery.",
            "timestamp": "2026-06-10T12:00:00Z",
        },
        *[
            {
                "id": f"failed-lara-search-{index}",
                "role": "assistant",
                "content": "I checked chats, but no mentions of Lara came up.",
                "timestamp": f"2026-06-12T12:{index:03d}:00Z",
            }
            for index in range(230)
        ],
    ]
    service = ChatContextService(store)

    _, memories, structured_context = await service.fetch_prompt_context(
        message="What did I say about Lara?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert all(not memory["id"].startswith("chat-") for memory in memories)
    assert any(
        item["id"] == "chat-lara-real-fact"
        for item in structured_context["chat_search_results"]
    )
    assert any(query.get("offset") == 200 for query in store.search_message_queries)
    status = structured_context["memory_status"]["source_statuses"][0]
    assert status["source"] == "chat_search"
    assert status["succeeded"] is True
    assert status["partial"] is False


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

    history, memories, structured_context = await service.fetch_prompt_context(
        message="Do you know anything about my mom?",
        conversation_id="conversation-1",
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert all(message["id"] != "same-conversation-mom" for message in history)
    assert all(not memory["id"].startswith("chat-") for memory in memories)
    assert any(
        item["id"] == "chat-conversation-1"
        for item in structured_context["chat_search_results"]
    )
    assert store.search_message_queries[0] == {
        "query": "Do you know anything about my mom?",
        "limit": 200,
        "exclude_conversation_id": None,
    }


@pytest.mark.asyncio
async def test_chat_context_returns_conversation_level_context_for_related_mom_details():
    store = FakeContextMemoryStore()
    store.past_messages = [
        {
            "id": "mom-birthday",
            "conversation_id": "conversation-old",
            "role": "user",
            "content": (
                "It's not next week, but on the eighteenth, it's my mom's "
                "birthday."
            ),
            "timestamp": "2026-06-12T18:48:00Z",
        },
        {
            "id": "mom-birthday-reply",
            "conversation_id": "conversation-old",
            "role": "assistant",
            "content": "Got it, June 18th is your mom's birthday.",
            "timestamp": "2026-06-12T18:48:10Z",
        },
        {
            "id": "mom-money",
            "conversation_id": "conversation-old",
            "role": "user",
            "content": "I intend to send her money around the 18th.",
            "timestamp": "2026-06-12T18:49:00Z",
        },
        {
            "id": "mom-money-reply",
            "conversation_id": "conversation-old",
            "role": "assistant",
            "content": "Want me to flag that?",
            "timestamp": "2026-06-12T18:49:10Z",
        },
    ]
    service = ChatContextService(store)

    _, memories, structured_context = await service.fetch_prompt_context(
        message="What do you know about my mom?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert all(not memory["id"].startswith("chat-") for memory in memories)
    result = structured_context["chat_search_results"][0]
    assert result["id"] == "chat-conversation-old"
    assert "mom's birthday" in result["content"]
    assert "send her money" in result["content"]
    assert "included nearby conversation context" in result["relevance_reason"]


@pytest.mark.asyncio
async def test_chat_context_uses_recent_subject_for_anything_else_followup():
    store = FakeContextMemoryStore()
    store.messages = [
        {
            "id": "message-1",
            "role": "user",
            "content": "What do you know about my mom?",
            "timestamp": "2026-06-12T19:00:00Z",
        },
        {
            "id": "message-2",
            "role": "assistant",
            "content": "From our chats, her birthday is June 18.",
            "timestamp": "2026-06-12T19:00:10Z",
        },
    ]
    store.past_messages = [
        {
            "id": "mom-birthday",
            "conversation_id": "conversation-old",
            "role": "user",
            "content": "My mom's birthday is June 18.",
            "timestamp": "2026-06-12T18:48:00Z",
        },
        {
            "id": "mom-money",
            "conversation_id": "conversation-old",
            "role": "user",
            "content": "I plan to send her a gift around the 18th.",
            "timestamp": "2026-06-12T18:49:00Z",
        },
    ]
    service = ChatContextService(store)

    _, _, structured_context = await service.fetch_prompt_context(
        message="Did I mention anything else about that?",
        conversation_id="conversation-1",
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    result = structured_context["chat_search_results"][0]
    assert result["id"] == "chat-conversation-old"
    assert "mom's birthday" in result["content"]
    assert "send her a gift" in result["content"]
    assert store.search_message_queries[0]["query"] == (
        "What do you know about my mom? Did I mention anything else about that?"
    )


@pytest.mark.asyncio
async def test_chat_context_searches_games_as_generic_conversation_history():
    store = FakeContextMemoryStore()
    store.past_messages = [
        {
            "id": "pc-game",
            "conversation_id": "conversation-games",
            "role": "user",
            "content": "Awesome. I'm going to buy my first PC game.",
            "timestamp": "2026-06-15T08:05:00Z",
        },
        {
            "id": "league",
            "conversation_id": "conversation-games",
            "role": "user",
            "content": "I mean, I played League of Legends.",
            "timestamp": "2026-06-15T08:06:00Z",
        },
        {
            "id": "legacy",
            "conversation_id": "conversation-games",
            "role": "user",
            "content": "It's Legacy of Kain.",
            "timestamp": "2026-06-15T08:07:00Z",
        },
    ]
    service = ChatContextService(store)

    _, memories, structured_context = await service.fetch_prompt_context(
        message="What games do I play?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert all(not memory["id"].startswith("chat-") for memory in memories)
    result = structured_context["chat_search_results"][0]
    assert result["id"] == "chat-conversation-games"
    assert "first PC game" in result["content"]
    assert "League of Legends" in result["content"]
    assert "Legacy of Kain" in result["content"]
    status = structured_context["memory_status"]["source_statuses"][0]
    assert "expanded_keywords" in status["query_modes"]
    assert any(
        "game" in item["query"]
        for item in status["queries"]
        if item["mode"] == "expanded_keywords"
    )


@pytest.mark.asyncio
async def test_chat_context_forces_chat_search_for_recall_even_when_intent_skips_memory():
    store = FakeContextMemoryStore()
    store.past_messages = [
        {
            "id": "pc-game",
            "conversation_id": "conversation-games",
            "role": "user",
            "content": "Awesome. I'm going to buy my first PC game.",
            "timestamp": "2026-06-15T08:05:00Z",
        },
        {
            "id": "legacy",
            "conversation_id": "conversation-games",
            "role": "user",
            "content": "It's Legacy of Kain.",
            "timestamp": "2026-06-15T08:07:00Z",
        },
    ]
    service = ChatContextService(store)

    _, memories, structured_context = await service.fetch_prompt_context(
        message="What was the game I wanted to buy?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.CASUAL),
    )

    assert all(not memory["id"].startswith("chat-") for memory in memories)
    result = structured_context["chat_search_results"][0]
    assert result["id"] == "chat-conversation-games"
    assert "first PC game" in result["content"]
    assert "Legacy of Kain" in result["content"]
    assert structured_context["memory_status"]["attempted_sources"][
        "long_term_memory"
    ] is True
    assert structured_context["memory_status"]["attempted_sources"][
        "chat_search"
    ] is True


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("message", "past_content", "expected_text"),
    [
        (
            "Do you remember when I talked about my EAD?",
            "We talked about my EAD renewal last month.",
            "EAD renewal",
        ),
        (
            "Did I ever say anything about sending money?",
            "I said I wanted to send money to my mama.",
            "send money",
        ),
        (
            "Can you search my history for brain?",
            "The word brain came up when we discussed Rex.",
            "word brain",
        ),
        (
            "What did we discuss about PC games?",
            "We discussed buying Legacy of Kain on PC.",
            "Legacy of Kain",
        ),
    ],
)
async def test_chat_context_broad_past_phrases_always_trigger_chat_search(
    message,
    past_content,
    expected_text,
):
    store = FakeContextMemoryStore()
    store.past_messages = [
        {
            "id": "broad-recall-match",
            "conversation_id": "conversation-broad",
            "role": "user",
            "content": past_content,
            "timestamp": "2026-06-18T12:00:00Z",
        }
    ]
    service = ChatContextService(store)

    _, _, structured_context = await service.fetch_prompt_context(
        message=message,
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.CASUAL),
    )

    result = structured_context["chat_search_results"][0]
    assert expected_text in result["content"]
    status = structured_context["memory_status"]["source_statuses"][0]
    assert status["source"] == "chat_search"
    assert status["attempted"] is True


@pytest.mark.asyncio
async def test_chat_context_full_scan_fallback_finds_manual_recall_examples():
    store = FakeContextMemoryStore(force_empty_search_messages=True)
    store.past_messages = [
        {
            "id": "mom-birthday",
            "conversation_id": "conversation-manual",
            "role": "user",
            "content": "My mom's birthday is June 18.",
            "timestamp": "2026-06-18T12:00:00Z",
        },
        {
            "id": "mom-money",
            "conversation_id": "conversation-manual",
            "role": "user",
            "content": "I want to send money to my mama around the 18th.",
            "timestamp": "2026-06-18T12:01:00Z",
        },
        {
            "id": "pc-game",
            "conversation_id": "conversation-manual",
            "role": "user",
            "content": "Awesome. I'm going to buy my first PC game.",
            "timestamp": "2026-06-18T12:02:00Z",
        },
        {
            "id": "legacy",
            "conversation_id": "conversation-manual",
            "role": "user",
            "content": "It's Legacy of Kain.",
            "timestamp": "2026-06-18T12:03:00Z",
        },
        {
            "id": "league",
            "conversation_id": "conversation-manual",
            "role": "user",
            "content": "I played League of Legends before.",
            "timestamp": "2026-06-18T12:04:00Z",
        },
    ]
    service = ChatContextService(store)

    _, _, structured_context = await service.fetch_prompt_context(
        message="What did I say about games, PC game, Legacy of Kain, my mom, and money?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.CASUAL),
    )

    result = structured_context["chat_search_results"][0]
    assert "mom's birthday is June 18" in result["content"]
    assert "send money to my mama" in result["content"]
    assert "first PC game" in result["content"]
    assert "Legacy of Kain" in result["content"]
    assert "League of Legends" in result["content"]
    status = structured_context["memory_status"]["source_statuses"][0]
    assert status["full_scan_used"] is True
    assert "full_scan" in status["query_modes"]


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("message", "expected_text"),
    [
        ("Search chats for mom", "mom's birthday"),
        ("Search chats for June", "June 18th"),
        ("Search chats for 18", "June 18th"),
        ("Search chats for June 18", "June 18th"),
        ("Search chats for PC game", "first PC game"),
        ("Search chats for Legacy of Kain", "Legacy of Kain"),
    ],
)
async def test_chat_context_keyword_search_finds_manual_cases_without_full_scan(
    message,
    expected_text,
):
    store = FakeContextMemoryStore()
    store.list_messages = None
    store.past_messages = [
        {
            "id": "mom-birthday",
            "conversation_id": "conversation-manual",
            "role": "user",
            "content": "My mom's birthday is June 18th.",
            "timestamp": "2026-06-18T12:00:00Z",
        },
        {
            "id": "pc-game",
            "conversation_id": "conversation-manual",
            "role": "user",
            "content": "Awesome. I'm going to buy my first PC game.",
            "timestamp": "2026-06-18T12:02:00Z",
        },
        {
            "id": "legacy",
            "conversation_id": "conversation-manual",
            "role": "user",
            "content": "It's Legacy of Kain.",
            "timestamp": "2026-06-18T12:03:00Z",
        },
    ]
    service = ChatContextService(store)

    _, _, structured_context = await service.fetch_prompt_context(
        message=message,
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    result = structured_context["chat_search_results"][0]
    assert result["id"] == "chat-conversation-manual"
    assert expected_text in result["content"]
    status = structured_context["memory_status"]["source_statuses"][0]
    assert status["full_scan_used"] is False
    assert status["source"] == "chat_search"


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("message", "expected_text"),
    [
        ("Do you have any idea of my mom's birthday?", "mom's birthday"),
        ("What did I say about games?", "first PC game"),
        ("Find old chats about Legacy of Kain", "Legacy of Kain"),
        ("Search chats for the eighteenth", "June 18th"),
    ],
)
async def test_chat_context_natural_recall_phrasing_triggers_old_chat_search(
    message,
    expected_text,
):
    store = FakeContextMemoryStore()
    store.list_messages = None
    store.past_messages = [
        {
            "id": "mom-birthday",
            "conversation_id": "conversation-manual",
            "role": "user",
            "content": "My mom's birthday is June 18th.",
            "timestamp": "2026-06-18T12:00:00Z",
        },
        {
            "id": "pc-game",
            "conversation_id": "conversation-manual",
            "role": "user",
            "content": "Awesome. I'm going to buy my first PC game.",
            "timestamp": "2026-06-18T12:02:00Z",
        },
        {
            "id": "legacy",
            "conversation_id": "conversation-manual",
            "role": "user",
            "content": "It's Legacy of Kain.",
            "timestamp": "2026-06-18T12:03:00Z",
        },
    ]
    service = ChatContextService(store)

    _, _, structured_context = await service.fetch_prompt_context(
        message=message,
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.CASUAL),
    )

    result = structured_context["chat_search_results"][0]
    assert expected_text in result["content"]
    status = structured_context["memory_status"]["source_statuses"][0]
    assert status["source"] == "chat_search"
    assert status["result_count"] > 0


@pytest.mark.asyncio
async def test_chat_context_finds_send_money_from_gift_followup():
    store = FakeContextMemoryStore()
    store.messages = [
        {
            "id": "message-1",
            "role": "user",
            "content": "What do you know about my mom?",
            "timestamp": "2026-06-12T19:00:00Z",
        },
        {
            "id": "message-2",
            "role": "assistant",
            "content": "From chats, her birthday is June 18.",
            "timestamp": "2026-06-12T19:00:10Z",
        },
    ]
    store.past_messages = [
        {
            "id": "mom-birthday",
            "conversation_id": "conversation-old",
            "role": "user",
            "content": "My mom's birthday is June 18.",
            "timestamp": "2026-06-12T18:48:00Z",
        },
        {
            "id": "mom-money",
            "conversation_id": "conversation-old",
            "role": "user",
            "content": "I intend to send her money around the 18th.",
            "timestamp": "2026-06-12T18:49:00Z",
        },
    ]
    service = ChatContextService(store)

    _, _, structured_context = await service.fetch_prompt_context(
        message="Did I mention giving her a gift?",
        conversation_id="conversation-1",
        intent_decision=RexIntentDecision(RexIntent.CASUAL),
    )

    result = structured_context["chat_search_results"][0]
    assert result["id"] == "chat-conversation-old"
    assert "mom's birthday" in result["content"]
    assert "send her money" in result["content"]
    assert structured_context["memory_status"]["attempted_sources"][
        "chat_search"
    ] is True


@pytest.mark.asyncio
async def test_chat_context_searches_short_pc_subject():
    store = FakeContextMemoryStore()
    store.past_messages = [
        {
            "id": "pc-game",
            "conversation_id": "conversation-pc",
            "role": "user",
            "content": "Awesome. I'm going to buy my first PC game.",
            "timestamp": "2026-06-15T08:05:00Z",
        },
        {
            "id": "legacy",
            "conversation_id": "conversation-pc",
            "role": "user",
            "content": "It's Legacy of Kain.",
            "timestamp": "2026-06-15T08:07:00Z",
        },
    ]
    service = ChatContextService(store)

    _, _, structured_context = await service.fetch_prompt_context(
        message="What did I say about my PC?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    result = structured_context["chat_search_results"][0]
    assert result["id"] == "chat-conversation-pc"
    assert "first PC game" in result["content"]
    assert "Legacy of Kain" in result["content"]


@pytest.mark.asyncio
async def test_chat_context_treats_old_chet_as_old_chat_recall():
    store = FakeContextMemoryStore()
    store.past_messages = [
        {
            "id": "mom-birthday",
            "conversation_id": "conversation-old",
            "role": "user",
            "content": "My mom's birthday is June 18.",
            "timestamp": "2026-06-12T18:48:00Z",
        },
    ]
    service = ChatContextService(store)

    _, _, structured_context = await service.fetch_prompt_context(
        message="Can you check the old Chet for my mom?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.CASUAL),
    )

    result = structured_context["chat_search_results"][0]
    assert result["id"] == "chat-conversation-old"
    assert "mom's birthday" in result["content"]
    status = structured_context["memory_status"]["source_statuses"][0]
    assert status["source"] == "chat_search"
    assert status["attempted"] is True


@pytest.mark.asyncio
async def test_chat_context_uses_wide_conversation_window_for_old_matches():
    store = FakeContextMemoryStore()
    store.past_messages = [
        {
            "id": f"message-{index}",
            "conversation_id": "conversation-long",
            "role": "user" if index in {10, 11, 12} else "assistant",
            "content": (
                "My mom's birthday is June 18."
                if index == 10
                else "I want to send money to my mama."
                if index == 11
                else "I am buying Legacy of Kain as my first PC game."
                if index == 12
                else f"filler message {index}"
            ),
            "timestamp": f"2026-06-18T12:{index:02d}:00Z",
        }
        for index in range(180)
    ]
    service = ChatContextService(store)

    _, _, structured_context = await service.fetch_prompt_context(
        message="What do you know about my mom?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.CASUAL),
    )

    result = structured_context["chat_search_results"][0]
    assert "mom's birthday is June 18" in result["content"]
    assert "send money to my mama" in result["content"]
    assert "Legacy of Kain" in result["content"]


@pytest.mark.asyncio
async def test_chat_context_keeps_factual_i_told_you_recall_messages():
    store = FakeContextMemoryStore()
    store.past_messages = [
        {
            "id": "pc-game",
            "conversation_id": "conversation-pc",
            "role": "user",
            "content": "Awesome. I'm going to buy my first PC game.",
            "timestamp": "2026-06-15T08:05:00Z",
        },
        {
            "id": "legacy",
            "conversation_id": "conversation-pc",
            "role": "user",
            "content": "It's Legacy of Kain.",
            "timestamp": "2026-06-15T08:07:00Z",
        },
        {
            "id": "pc-complaint-with-fact",
            "conversation_id": "conversation-pc",
            "role": "user",
            "content": "Didn't I told you that I would buy a PC game?",
            "timestamp": "2026-06-18T08:09:00Z",
        },
    ]
    service = ChatContextService(store)

    _, _, structured_context = await service.fetch_prompt_context(
        message="Did I tell you I would buy a PC game?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.CASUAL),
    )

    result = structured_context["chat_search_results"][0]
    assert result["id"] == "chat-conversation-pc"
    assert "first PC game" in result["content"]
    assert "Legacy of Kain" in result["content"]
    assert "would buy a PC game" in result["content"]
    status = structured_context["memory_status"]["source_statuses"][0]
    assert "keyword" in status["query_modes"]
    assert any(item["query"] in {"pc", "game", "games"} for item in status["queries"])


@pytest.mark.asyncio
async def test_chat_context_searches_send_money_with_generic_keyword_terms():
    store = FakeContextMemoryStore()
    store.past_messages = [
        {
            "id": "mom-birthday",
            "conversation_id": "conversation-old",
            "role": "user",
            "content": "It's not next week, but on the eighteenth, it's my mom's birthday.",
            "timestamp": "2026-06-12T18:48:00Z",
        },
        {
            "id": "mom-money",
            "conversation_id": "conversation-old",
            "role": "user",
            "content": "Ten to send her around.",
            "timestamp": "2026-06-12T18:49:00Z",
        },
        {
            "id": "mom-money-reply",
            "conversation_id": "conversation-old",
            "role": "assistant",
            "content": "Got it, you intend to send something around the 18th for her birthday.",
            "timestamp": "2026-06-12T18:49:10Z",
        },
    ]
    service = ChatContextService(store)

    _, _, structured_context = await service.fetch_prompt_context(
        message="Do you know if I mentioned sending money to someone?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.CASUAL),
    )

    result = structured_context["chat_search_results"][0]
    assert result["id"] == "chat-conversation-old"
    assert "mom's birthday" in result["content"]
    assert "send her around" in result["content"]
    assert "send something around the 18th" in result["content"]
    status = structured_context["memory_status"]["source_statuses"][0]
    assert "keyword" in status["query_modes"]
    assert any(item["query"] == "send" for item in status["queries"])


@pytest.mark.asyncio
async def test_chat_context_searches_arbitrary_immigration_topic():
    store = FakeContextMemoryStore()
    store.past_messages = [
        {
            "id": "immigration-ead",
            "conversation_id": "conversation-immigration",
            "role": "user",
            "content": "My EAD renewal and USCIS paperwork are due soon.",
            "timestamp": "2026-06-10T10:00:00Z",
        },
        {
            "id": "immigration-plan",
            "conversation_id": "conversation-immigration",
            "role": "user",
            "content": "I need to check my immigration status before the trip.",
            "timestamp": "2026-06-10T10:01:00Z",
        },
    ]
    service = ChatContextService(store)

    _, memories, structured_context = await service.fetch_prompt_context(
        message="What did I say about immigration?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    assert all(not memory["id"].startswith("chat-") for memory in memories)
    result = structured_context["chat_search_results"][0]
    assert result["id"] == "chat-conversation-immigration"
    assert "EAD renewal" in result["content"]
    assert "immigration status" in result["content"]
    assert result["relevance_score"] > 0
    assert result["query_modes"]


@pytest.mark.asyncio
async def test_chat_context_searches_arbitrary_purchase_and_object_topics():
    store = FakeContextMemoryStore()
    store.past_messages = [
        {
            "id": "chair-purchase",
            "conversation_id": "conversation-purchase",
            "role": "user",
            "content": "I am buying an ergonomic chair for the desk setup.",
            "timestamp": "2026-06-10T10:00:00Z",
        },
        {
            "id": "monitor-object",
            "conversation_id": "conversation-purchase",
            "role": "user",
            "content": "The monitor I liked was the ultrawide one.",
            "timestamp": "2026-06-10T10:01:00Z",
        },
    ]
    service = ChatContextService(store)

    _, _, structured_context = await service.fetch_prompt_context(
        message="Search chats for purchases",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    result = structured_context["chat_search_results"][0]
    assert result["id"] == "chat-conversation-purchase"
    assert "ergonomic chair" in result["content"]

    _, _, structured_context = await service.fetch_prompt_context(
        message="What did I say about the monitor?",
        conversation_id=None,
        intent_decision=RexIntentDecision(RexIntent.MEMORY_RECALL),
    )

    result = structured_context["chat_search_results"][0]
    assert result["id"] == "chat-conversation-purchase"
    assert "ultrawide" in result["content"]


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
        {"source": "chat_search", "message": "past chat search failed"}
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

from app.services.prompt_service import (
    ACCOUNTABILITY_CONTEXT_PREFIX,
    FILE_CONTEXT_PREFIX,
    FINANCIAL_CONTEXT_PREFIX,
    LONG_TERM_MEMORY_PREFIX,
    MAX_DEFAULT_REX_PROMPT_CHARACTERS,
    PERSONALITY_CONTEXT_PREFIX,
    PromptService,
    REX_PERSONALITY_PROMPT,
    STRUCTURED_MEMORY_PREFIX,
)
from app.services.time_context_service import TimeContextService

BASE_SYSTEM_PROMPT = f"{PERSONALITY_CONTEXT_PREFIX}{REX_PERSONALITY_PROMPT}"


def test_prompt_service_always_includes_rex_personality():
    service = PromptService()

    messages = service.build_messages(user_message="Hello Rex")

    assert messages == [
        {
            "role": "system",
            "content": BASE_SYSTEM_PROMPT,
        },
        {"role": "user", "content": "Hello Rex"},
    ]
    assert len(messages[0]["content"]) <= MAX_DEFAULT_REX_PROMPT_CHARACTERS
    assert "private, voice-first AI companion" in messages[0]["content"]
    assert "Answer casual turns fast and briefly" in messages[0]["content"]
    assert "Memory/action rules:" not in messages[0]["content"]
    assert "execution metadata confirms success" not in messages[0]["content"]


def test_prompt_service_sanitizes_recent_message_history():
    service = PromptService()

    messages = service.build_messages(
        user_message="What now?",
        recent_messages=[
            {
                "id": "message-1",
                "role": "user",
                "content": "Earlier user message",
                "timestamp": "2026-05-12T12:00:00Z",
            },
            {
                "id": "message-2",
                "role": "assistant",
                "content": "Earlier assistant response",
                "timestamp": "2026-05-12T12:01:00Z",
            },
            {"role": "tool", "content": "Ignored unsupported role"},
            {"role": "user", "content": ""},
        ],
    )

    assert messages == [
        {
            "role": "system",
            "content": BASE_SYSTEM_PROMPT,
        },
        {"role": "user", "content": "Earlier user message"},
        {"role": "assistant", "content": "Earlier assistant response"},
        {"role": "user", "content": "What now?"},
    ]


def test_prompt_service_injects_time_conversation_memory_and_file_context():
    service = PromptService(TimeContextService(timezone_name="America/New_York"))

    messages = service.build_messages(
        user_message="Read this and help me decide.",
        recent_messages=[
            {"role": "assistant", "content": "What happened?"},
        ],
        relevant_memories=[
            {
                "memory_type": "preference",
                "content": "I prefer direct concise answers.",
                "created_at": "2026-04-30T15:30:00-04:00",
                "relevance_reason": "Included high-priority user preference.",
            },
        ],
        file_context="Budget notes",
        conversation_metadata={
            "id": "conversation-1",
            "title": "Budget review",
            "timestamp": "2026-05-12T10:00:00Z",
            "last_message_timestamp": "2026-05-12T14:00:00Z",
        },
        time_context={
            "clock_context": "Tuesday afternoon (15:30 America/New_York (EDT))",
            "iso_timestamp": "2026-05-12T15:30:00-04:00",
            "date": "2026-05-12",
            "weekday": "Tuesday",
            "time": "15:30",
            "timezone": "America/New_York (EDT)",
            "previous_timestamp_delta": "earlier today",
        },
    )

    assert messages[0]["role"] == "system"
    system_content = messages[0]["content"]
    assert system_content.startswith(PERSONALITY_CONTEXT_PREFIX)
    assert "warm, direct, honest, practical, and natural" in system_content
    assert "Memory/action rules:" in system_content
    assert "backend-confirmed saves, updates, or deletes" in system_content
    assert "Saved memory is not chat history" in system_content
    assert "Current time context:" in system_content
    assert "- Clock: Tuesday afternoon" in system_content
    assert "- Previous message delta: earlier today" in system_content
    assert "Conversation context:" in system_content
    assert "- Conversation ID: conversation-1" in system_content
    assert LONG_TERM_MEMORY_PREFIX in system_content
    assert "- preference: I prefer direct concise answers." in system_content
    assert "saved 12 days ago" in system_content
    assert "why recalled: Included high-priority user preference." in system_content
    assert messages[-3] == {"role": "assistant", "content": "What happened?"}
    assert messages[-2] == {
        "role": "user",
        "content": f"{FILE_CONTEXT_PREFIX}Budget notes",
    }
    assert messages[-1] == {
        "role": "user",
        "content": "Read this and help me decide.",
    }


def test_prompt_service_injects_unified_financial_context():
    service = PromptService()

    messages = service.build_messages(
        user_message="How am I doing financially?",
        financial_context={
            "schema": "clarity_unified_financial_context_v1",
            "generated_at": "2026-05-22T20:00:00Z",
            "data_status": {
                "state": "ready",
                "financial_context_complete": True,
                "load_errors": [],
            },
            "freshness": {"state": "fresh"},
            "integration": {
                "mode": "unified_clarity_rex",
                "raw_transactions_included": True,
                "account_names_included": True,
                "merchant_names_included": True,
            },
            "available_controls": {
                "transactions": ["create_transaction", "update_transaction"],
                "accounts": ["create_account", "update_account"],
            },
            "period": {
                "reference_month": "2026-05",
                "transaction_count": 42,
                "first_transaction_date": "2026-05-01",
                "last_transaction_date": "2026-05-22",
            },
            "cash_flow": {
                "total_balance": 5000.25,
                "income_this_month": 4200,
                "spent_this_month": 3100.50,
                "available_this_month": 1099.50,
                "burn_runway_days": 48,
            },
            "budget": {
                "period_type": "monthly",
                "period_key": "2026-05",
                "total_budgeted": 3000,
                "total_spent": 3100.50,
                "total_remaining": -100.50,
                "total_overspent": 100.50,
                "budgeted_category_count": 8,
            },
            "top_spending_categories": [
                {"category": "Food", "spent": 900},
                {"category": "Transport", "spent": 300},
            ],
            "biggest_month_over_month_increases": [
                {
                    "category": "Food",
                    "spent_last_month": 500,
                    "spent_this_month": 900,
                    "percent_change": 80,
                }
            ],
            "transaction_slices": {
                "review_queues": [
                    {
                        "key": "needsCategory",
                        "label": "Uncategorized review",
                        "transaction_count": 6,
                        "spend": 59.5,
                        "income": 0,
                        "net": -59.5,
                        "latest_date": "2026-05-21",
                        "user_facing_category": False,
                        "detail_status": "all_rows_included",
                        "included_sample_count": 6,
                        "sample_transactions": [
                            {
                                "id": "transaction-1",
                                "date": "2026-05-21",
                                "description": "Coffee Shop",
                                "amount": -24.5,
                            },
                            {
                                "id": "transaction-2",
                                "date": "2026-05-20",
                                "description": "Unknown Merchant 2",
                                "amount": -5,
                            },
                            {
                                "id": "transaction-3",
                                "date": "2026-05-19",
                                "description": "Unknown Merchant 3",
                                "amount": -6,
                            },
                            {
                                "id": "transaction-4",
                                "date": "2026-05-18",
                                "description": "Unknown Merchant 4",
                                "amount": -7,
                            },
                            {
                                "id": "transaction-5",
                                "date": "2026-05-17",
                                "description": "Unknown Merchant 5",
                                "amount": -8,
                            },
                            {
                                "id": "transaction-6",
                                "date": "2026-05-16",
                                "description": "Unknown Merchant 6",
                                "amount": -9,
                            },
                        ],
                    }
                ]
            },
            "accounts": [
                {
                    "id": "account-1",
                    "name": "Main Checking",
                    "type": "checking",
                    "current_balance": 5000.25,
                }
            ],
            "categories": [
                {
                    "id": "category-1",
                    "name": "Food",
                    "type": "expense",
                }
            ],
            "budgets": [
                {
                    "id": "budget-1",
                    "name": "Food",
                    "amount": 700,
                    "period": "monthly",
                }
            ],
            "transactions": [
                {
                    "id": "transaction-1",
                    "date": "2026-05-21",
                    "account_id": "account-1",
                    "account_name": "Main Checking",
                    "category_id": "category-1",
                    "category_name": "Food",
                    "amount": 24.5,
                    "type": "expense",
                    "merchant": "Coffee Shop",
                    "description": "Coffee Shop",
                }
            ],
        },
    )

    system_content = messages[0]["content"]
    assert FINANCIAL_CONTEXT_PREFIX in system_content
    assert "Rex is inside Clarity" in system_content
    assert "specific accounts, account names, budgets" in system_content
    assert "Review queues are not user-facing dashboard categories" in system_content
    assert (
        "Do not offer to pull, check, fetch, or list transaction details later"
        in system_content
    )
    assert "Data status: state=ready; complete=True; freshness=fresh" in system_content
    assert "reference_month=2026-05" in system_content
    assert "spent_this_month=3100.5" in system_content
    assert "Food=900" in system_content
    assert "Food: 500 -> 900 (80%)" in system_content
    assert "Main Checking" in system_content
    assert "Coffee Shop" in system_content
    assert "Unknown Merchant 6" in system_content
    assert "Category data issue count=6" in system_content
    assert "user_facing_category=false" in system_content
    assert "review_queue_not_dashboard_category" in system_content
    assert "sample_transactions" in system_content
    assert "create_transaction" in system_content


def test_prompt_service_marks_aggregate_only_review_queue_without_rows():
    service = PromptService()

    messages = service.build_messages(
        user_message="List uncategorized transactions.",
        financial_context={
            "schema": "clarity_unified_financial_context_v1",
            "generated_at": "2026-06-12T20:00:00Z",
            "data_status": {
                "state": "ready",
                "financial_context_complete": True,
                "load_errors": [],
            },
            "transaction_slices": {
                "review_queues": [
                    {
                        "key": "needsCategory",
                        "label": "Uncategorized review",
                        "transaction_count": 36,
                        "spend": 36,
                        "income": 0,
                        "net": -36,
                        "latest_date": "2026-06-07",
                        "user_facing_category": False,
                    }
                ]
            },
        },
    )

    system_content = messages[0]["content"]
    assert "Category data issue count=36" in system_content
    assert "user_facing_category=false" in system_content
    assert "review_queue_not_dashboard_category" in system_content
    assert "detail_status=aggregate_only" in system_content
    assert "exact rows are not included in this turn" in system_content


def test_prompt_service_warns_when_financial_context_is_degraded_or_stale():
    service = PromptService()

    messages = service.build_messages(
        user_message="Can I spend more this week?",
        financial_context={
            "schema": "clarity_unified_financial_context_v1",
            "generated_at": "2026-05-22T20:00:00Z",
            "data_status": {
                "state": "degraded",
                "financial_context_complete": False,
                "load_errors": [
                    {
                        "source": "transactions",
                        "message": "Could not fetch transactions.",
                    }
                ],
            },
            "freshness": {
                "state": "stale",
                "stale_plaid_accounts": [
                    {
                        "account_id": "account-1",
                        "account_name": "Bank Checking • 1234",
                        "age_hours": 30,
                    }
                ],
            },
            "available_controls": {"transactions": ["update_transaction"]},
        },
    )

    system_content = messages[0]["content"]
    assert "state=degraded" in system_content
    assert "freshness=stale" in system_content
    assert (
        "Rex must explicitly tell the user this financial data is not fully reliable"
        in system_content
    )
    assert "Could not fetch transactions" in system_content


def test_prompt_service_injects_structured_memory_before_generic_memory():
    service = PromptService(TimeContextService(timezone_name="America/New_York"))

    messages = service.build_messages(
        user_message="I saw Clara and ordered DoorDash again.",
        relevant_memories=[
            {
                "memory_type": "event",
                "content": "I said DoorDash was hurting my budget.",
            },
        ],
        structured_context={
            "entities": [
                {
                    "id": "entity-clara",
                    "entity_type": "person",
                    "display_name": "Clara",
                    "relationship": "dating interest from work",
                    "summary": "Clara touched my arm and matters to the dating story.",
                    "relevance_reason": "Matched current message terms: clara",
                }
            ],
            "entity_events": [
                {
                    "entity_id": "entity-clara",
                    "event_type": "interaction",
                    "title": "Clara touched my arm",
                    "content": "This felt like flirting at work.",
                    "occurred_at": "2026-05-18T12:00:00Z",
                }
            ],
            "personal_rules": [
                {
                    "rule_type": "finance",
                    "title": "Avoid DoorDash",
                    "rule_text": "Do not order DoorDash while the budget is slipping.",
                    "relevance_reason": "Matched current message terms: doordash",
                }
            ],
            "plans": [
                {
                    "id": "plan-visa",
                    "plan_type": "immigration",
                    "title": "Visa runway",
                    "desired_outcome": "Leave with enough money and clean paperwork.",
                    "target_date": "2026-07-01",
                    "relevance_reason": "Matched current message terms: visa",
                }
            ],
            "plan_milestones": [
                {
                    "plan_id": "plan-visa",
                    "milestone_type": "deadline",
                    "title": "Prepare immigration documents",
                    "target_date": "2026-06-01",
                }
            ],
            "commitments": [
                {
                    "commitment_type": "deadline",
                    "title": "Review visa paperwork",
                    "commitment_text": "Review the visa documents before June.",
                    "plan_id": "plan-visa",
                    "due_at": "2026-05-31T18:00:00Z",
                    "relevance_reason": "Matched current message terms: visa",
                }
            ],
        },
    )

    system_content = messages[0]["content"]
    assert system_content.index(STRUCTURED_MEMORY_PREFIX) < system_content.index(
        LONG_TERM_MEMORY_PREFIX
    )
    assert (
        "- saved knowledge/person Clara - dating interest from work" in system_content
    )
    assert "Clara touched my arm and matters to the dating story." in system_content
    assert "- entity_event/interaction for Clara: Clara touched my arm" in (
        system_content
    )
    assert "- rule/finance Avoid DoorDash: Do not order DoorDash" in system_content
    assert "- plan/immigration Visa runway: Leave with enough money" in system_content
    assert "- milestone/deadline for Visa runway: Prepare immigration documents" in (
        system_content
    )
    assert "- commitment/deadline Review visa paperwork" in system_content
    assert "plan: Visa runway" in system_content


def test_prompt_service_labels_plan_with_linked_person():
    service = PromptService(TimeContextService(timezone_name="America/New_York"))

    messages = service.build_messages(
        user_message="What do you remember about the date plan?",
        structured_context={
            "entities": [
                {
                    "id": "entity-melissa",
                    "entity_type": "person",
                    "display_name": "Melissa",
                    "relationship": "dating interest from work",
                }
            ],
            "plans": [
                {
                    "id": "plan-date",
                    "plan_type": "dating",
                    "title": "Dinner invitation",
                    "desired_outcome": "Successful date.",
                    "primary_entity_id": "entity-melissa",
                    "relevance_reason": "Matched current message terms: date, plan",
                }
            ],
        },
    )

    system_content = messages[0]["content"]
    assert "- plan/dating Dinner invitation for Melissa: Successful date." in (
        system_content
    )


def test_prompt_service_injects_accountability_before_generic_memory():
    service = PromptService(TimeContextService(timezone_name="America/New_York"))

    messages = service.build_messages(
        user_message="I ordered DoorDash again.",
        relevant_memories=[
            {
                "memory_type": "event",
                "content": "I committed to stop ordering DoorDash in May.",
            }
        ],
        accountability_signals=[
            {
                "signal_type": "rule_violation",
                "severity": "high",
                "confidence": 0.87,
                "title": "Possible rule violation: Avoid DoorDash",
                "reason": "The message matched active DoorDash rule triggers.",
                "source_refs": [
                    {
                        "source_type": "personal_rule",
                        "title": "Avoid DoorDash",
                        "excerpt": "Do not order DoorDash while the budget is slipping.",
                    }
                ],
                "suggested_prompt": (
                    "You said DoorDash was off-limits while the budget is slipping."
                ),
                "recommended_action": "Hold the user to the rule.",
            }
        ],
    )

    system_content = messages[0]["content"]
    assert ACCOUNTABILITY_CONTEXT_PREFIX in system_content
    assert system_content.index(ACCOUNTABILITY_CONTEXT_PREFIX) < system_content.index(
        LONG_TERM_MEMORY_PREFIX
    )
    assert (
        "- rule_violation/high: Possible rule violation: Avoid DoorDash"
        in system_content
    )
    assert "confidence: 0.87" in system_content
    assert "sources: personal_rule:Avoid DoorDash" in system_content
    assert "Suggested framing: You said DoorDash was off-limits" in system_content
    assert "Action: Hold the user to the rule." in system_content


def test_prompt_service_surfaces_degraded_memory_status():
    service = PromptService(TimeContextService(timezone_name="America/New_York"))

    messages = service.build_messages(
        user_message="Do you know anything about my mom?",
        structured_context={
            "memory_status": {
                "state": "degraded",
                "message": "Some memory sources could not be searched.",
                "failures": [
                    {
                        "source": "chat_search",
                        "message": "past chat search failed",
                    }
                ],
            }
        },
    )

    system_content = messages[0]["content"]
    assert STRUCTURED_MEMORY_PREFIX in system_content
    assert "recall_status" in system_content
    assert "chat_search=degraded" in system_content
    assert "Failed sources: chat_search" in system_content
    assert "search is temporarily unavailable" in system_content


def test_prompt_service_surfaces_empty_chat_search_status():
    service = PromptService(TimeContextService(timezone_name="America/New_York"))

    messages = service.build_messages(
        user_message="Do you know anything about my mom?",
        structured_context={
            "memory_status": {
                "state": "ready",
                "message": "Memory sources searched successfully.",
                "source_statuses": [
                    {
                        "source": "chat_search",
                        "attempted": True,
                        "succeeded": True,
                        "result_count": 0,
                        "raw_match_count": 0,
                        "partial": False,
                    }
                ],
            }
        },
    )

    system_content = messages[0]["content"]
    assert STRUCTURED_MEMORY_PREFIX in system_content
    assert "recall_status" in system_content
    assert "chat_search=empty count=0" in system_content
    assert "searched saved memory and old chats" in system_content
    assert "anything about that" in system_content


def test_prompt_service_surfaces_found_chat_search_status():
    service = PromptService(TimeContextService(timezone_name="America/New_York"))

    messages = service.build_messages(
        user_message="What did I say about PC games?",
        structured_context={
            "memory_status": {
                "state": "ready",
                "message": "Memory sources searched successfully.",
                "source_statuses": [
                    {
                        "source": "chat_search",
                        "attempted": True,
                        "succeeded": True,
                        "result_count": 2,
                        "raw_match_count": 4,
                        "partial": False,
                    }
                ],
            },
            "chat_search_results": [
                {
                    "content": "user: I am buying Legacy of Kain on PC.",
                    "timestamp": "2026-06-18T12:00:00Z",
                }
            ],
        },
    )

    system_content = messages[0]["content"]
    assert "recall_status" in system_content
    assert "chat_search=found count=2" in system_content
    assert "Chat history, not saved memory:" in system_content
    assert "- Chat history, not saved memory: user: I am buying Legacy" in system_content


def test_prompt_service_phase3_prompt_shapes_are_labeled_and_compact():
    service = PromptService()

    normal_messages = service.build_messages(user_message="Hey Rex")
    assert normal_messages[0]["content"] == BASE_SYSTEM_PROMPT
    assert "recall_status" not in normal_messages[0]["content"]
    assert "Chat history, not saved memory:" not in normal_messages[0]["content"]
    assert FINANCIAL_CONTEXT_PREFIX not in normal_messages[0]["content"]

    recall_messages = service.build_messages(
        user_message="What did I say about Legacy of Kain?",
        relevant_memories=[
            {
                "memory_type": "preference",
                "content": "I like concise answers.",
            }
        ],
        structured_context={
            "memory_status": {
                "attempted_sources": {
                    "long_term_memory": True,
                    "chat_search": True,
                },
                "source_statuses": [
                    {
                        "source": "chat_search",
                        "attempted": True,
                        "succeeded": True,
                        "result_count": 1,
                    }
                ],
            },
            "chat_search_results": [
                {
                    "content": "user: I am buying Legacy of Kain on PC.",
                }
            ],
        },
    )
    recall_prompt = recall_messages[0]["content"]
    assert (
        "recall_status: saved_knowledge=found count=1; chat_search=found count=1"
        in recall_prompt
    )
    assert LONG_TERM_MEMORY_PREFIX in recall_prompt
    assert "Chat history, not saved memory:" in recall_prompt
    assert "- Chat history, not saved memory: user: I am buying Legacy" in recall_prompt
    assert "chat_search_status/" not in recall_prompt

    finance_messages = service.build_messages(
        user_message="How am I doing financially?",
        financial_context={
            "data_status": {
                "state": "ready",
                "financial_context_complete": True,
                "load_errors": [],
            },
            "freshness": {"state": "fresh"},
            "cash_flow": {"total_balance": 100},
        },
    )
    finance_prompt = finance_messages[0]["content"]
    assert FINANCIAL_CONTEXT_PREFIX in finance_prompt
    assert "Cash flow: balance=100" in finance_prompt
    assert "recall_status" not in finance_prompt
    assert "Chat history, not saved memory:" not in finance_prompt

    voice_messages = service.build_messages(user_message="Voice hello")
    assert voice_messages[0]["content"] == BASE_SYSTEM_PROMPT

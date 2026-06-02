from app.services.rex_brain import RexBrainInput, RexThinkingRouter
from app.services.rex_brain_context import (
    BUDGET_LIMITS,
    RexBrainContext,
    RexContextBudgetLimits,
    RexFinancialContextScope,
    _enforce_total_budget,
    build_rex_brain_context,
)
from app.services.rex_brain_contracts import RexContextBudget, RexThinkingLayer


def test_context_requirements_map_matches_router_decision_sources():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Plan my budget around my relocation goal",
            has_financial_context=True,
            has_structured_memory=True,
            has_goals=True,
            has_pending_commitments=True,
        )
    )

    context = build_rex_brain_context(
        decision=decision,
        financial_context=_financial_context(),
        relevant_memories=[_memory("memory-1", "preference", "Prefer direct plans")],
        structured_context={
            "plans": [_plan("plan-1", "Relocate to Italy")],
            "plan_milestones": [_milestone("milestone-1", "Book visa consult")],
            "commitments": [_commitment("commitment-1", "Send visa documents")],
        },
        accountability_signals=[{"id": "signal-1", "severity": "high"}],
    )

    assert decision.layer == RexThinkingLayer.STRATEGIC
    assert decision.expected_context_sources == (
        "financial",
        "memory",
        "goals",
        "pending_commitments",
    )
    assert context.financial_scope == RexFinancialContextScope.FULL_ROLLUP
    assert context.financial_context is not None
    assert [memory["id"] for memory in context.relevant_memories] == ["memory-1"]
    assert [plan["id"] for plan in context.structured_context["plans"]] == ["plan-1"]
    assert [signal["id"] for signal in context.accountability_signals] == [
        "signal-1"
    ]


def test_missing_financial_context_creates_diagnostic_not_crash():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Analyze my spending",
            has_financial_context=True,
        )
    )

    context = build_rex_brain_context(
        decision=decision,
        financial_context=None,
    )

    assert context.financial_context is None
    assert "financial_context_missing" in context.diagnostics
    assert context.metadata()["financial_context_present"] is False


def test_degraded_financial_context_keeps_safe_metadata():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Analyze my spending",
            has_financial_context=True,
        )
    )

    context = build_rex_brain_context(
        decision=decision,
        financial_context={
            **_financial_context(),
            "data_status": "degraded",
            "load_errors": ["transactions_timeout"],
            "supabase_service_role_secret": "never include this",
        },
    )

    assert "financial_context_degraded" in context.diagnostics
    assert "financial_context_degraded:transactions_timeout" in context.diagnostics
    assert "supabase_service_role_secret" not in str(context.financial_context)
    assert "never include this" not in str(context.financial_context)


def test_nested_financial_status_metadata_does_not_crash():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Analyze my spending",
            has_financial_context=True,
        )
    )

    context = build_rex_brain_context(
        decision=decision,
        financial_context={
            **_financial_context(),
            "data_status": {"status": "ready"},
            "load_errors": {"transactions": "timeout"},
        },
    )

    assert context.financial_context is not None
    assert "financial_context_data_status_invalid" in context.diagnostics
    assert "financial_context_degraded" in context.diagnostics


def test_financial_summary_budget_excludes_raw_transactions():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="How much did I spend?",
            has_financial_context=True,
        )
    )

    context = build_rex_brain_context(
        decision=decision,
        financial_context=_financial_context(transaction_count=20),
    )

    assert context.financial_scope == RexFinancialContextScope.CURRENT_MONTH_ROLLUP
    assert context.financial_context is not None
    assert "transactions" not in context.financial_context
    assert context.character_count <= BUDGET_LIMITS[RexContextBudget.MEDIUM].total_characters


def test_large_selected_financial_records_are_capped_and_diagnosed():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Deep think and analyze thoroughly why my transactions changed",
            has_financial_context=True,
            user_requested_deep_thinking=True,
        )
    )

    context = build_rex_brain_context(
        decision=decision,
        financial_context=_financial_context(transaction_count=250),
    )

    assert context.financial_scope == RexFinancialContextScope.SELECTED_RECORDS
    assert context.financial_context is not None
    assert len(context.financial_context.get("transactions") or []) < 250
    assert "financial_context_truncated" in context.diagnostics
    assert context.character_count <= BUDGET_LIMITS[RexContextBudget.HIGH].total_characters


def test_memory_context_ranks_corrections_before_older_facts():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="What did we decide about my relocation?",
            has_structured_memory=True,
        )
    )

    context = build_rex_brain_context(
        decision=decision,
        relevant_memories=[
            _memory(
                "memory-old",
                "fact",
                "The relocation plan is Greece.",
                importance=5,
                updated_at="2026-05-01T00:00:00Z",
            ),
            _memory(
                "memory-correction",
                "correction",
                "Correction: the relocation plan is Italy first.",
                importance=3,
                updated_at="2026-05-20T00:00:00Z",
            ),
        ],
    )

    assert [memory["id"] for memory in context.relevant_memories] == [
        "memory-correction",
        "memory-old",
    ]


def test_goals_and_pending_items_context_are_selected_for_strategic_turns():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="Plan my next month goal and pending commitments",
            has_structured_memory=True,
            has_goals=True,
            has_pending_commitments=True,
        )
    )

    context = build_rex_brain_context(
        decision=decision,
        structured_context={
            "plans": [_plan("plan-app", "Ship Rex Brain")],
            "plan_milestones": [_milestone("milestone-app", "Finish context layer")],
            "commitments": [_commitment("commitment-demo", "Record phone demo")],
        },
        accountability_signals=[
            {"id": "signal-low", "severity": "low", "priority": 1},
            {"id": "signal-critical", "severity": "critical", "priority": 2},
        ],
    )

    assert [plan["id"] for plan in context.structured_context["plans"]] == [
        "plan-app"
    ]
    assert [item["id"] for item in context.structured_context["commitments"]] == [
        "commitment-demo"
    ]
    assert [signal["id"] for signal in context.accountability_signals] == [
        "signal-critical",
        "signal-low",
    ]


def test_context_safety_filter_removes_secrets_from_every_context_source():
    decision = RexThinkingRouter().route(
        RexBrainInput(
            message="What did we decide?",
            has_structured_memory=True,
        )
    )

    context = build_rex_brain_context(
        decision=decision,
        relevant_memories=[
            {
                "id": "memory-1",
                "memory_type": "fact",
                "content": "Safe memory",
                "access_token": "token-123",
            }
        ],
        structured_context={
            "personal_rules": [
                {
                    "id": "rule-1",
                    "title": "Safe rule",
                    "private_key": "secret-key",
                }
            ]
        },
        accountability_signals=[
            {
                "id": "signal-1",
                "severity": "high",
                "credentials": "secret-creds",
            }
        ],
    )

    rendered = str(context)
    assert "token-123" not in rendered
    assert "secret-key" not in rendered
    assert "secret-creds" not in rendered
    assert "Safe memory" in rendered


def test_recent_messages_are_sanitized_and_capped():
    decision = RexThinkingRouter().route(RexBrainInput(message="hey"))

    context = build_rex_brain_context(
        decision=decision,
        recent_messages=[
            {"role": "tool", "content": "ignore this"},
            {"role": "user", "content": "hello"},
            {"role": "assistant", "content": "hi"},
            {"role": "user", "content": "x" * 2000},
        ],
    )

    assert [message["role"] for message in context.recent_messages] == ["user"]
    assert context.recent_messages[0]["content"].endswith("[truncated]")
    assert "recent_chat_context_truncated" in context.diagnostics


def test_total_context_budget_is_enforced_after_bucket_selection():
    long_text = "x" * 1000
    context = RexBrainContext(
        context_budget=RexContextBudget.SMALL,
        financial_context={"transactions": [{"description": long_text} for _ in range(5)]},
        recent_messages=[
            {"role": "user", "content": f"older message {index} {long_text}"}
            for index in range(5)
        ],
        relevant_memories=tuple(
            _memory(f"memory-{index}", "fact", f"Important detail {index} {long_text}")
            for index in range(5)
        ),
        structured_context={
            "plans": tuple(
                _plan(f"plan-{index}", f"Plan {index} {long_text}")
                for index in range(5)
            ),
            "commitments": tuple(
                _commitment(f"commitment-{index}", f"Commitment {index} {long_text}")
                for index in range(5)
            ),
        },
        accountability_signals=tuple(
            {"id": f"signal-{index}", "severity": "high", "reason": long_text}
            for index in range(5)
        ),
    )
    limits = RexContextBudgetLimits(
        total_characters=2000,
        financial_characters=1000,
        memory_characters=1000,
        structured_characters=1000,
        accountability_characters=1000,
        recent_chat_characters=1000,
    )

    fitted = _enforce_total_budget(context, limits, [])

    assert fitted.character_count <= limits.total_characters
    assert "context_total_budget_exceeded" in fitted.diagnostics


def _financial_context(transaction_count: int = 3) -> dict:
    return {
        "schema": "clarity_unified_financial_context_v1",
        "generated_at": "2026-05-28T12:00:00Z",
        "data_status": "ready",
        "period": {"reference_month": "2026-05", "transaction_count": transaction_count},
        "cash_flow": {"income_this_month": 4000, "spent_this_month": 2500},
        "budget": {"total_budgeted": 3000, "total_remaining": 500},
        "top_spending_categories": [{"category": "Food", "spent": 800}],
        "accounts": [{"id": "account-1", "name": "Checking"}],
        "categories": [{"id": "category-1", "name": "Food"}],
        "budgets": [{"id": "budget-1", "category": "Food", "amount": 700}],
        "transaction_slices": {
            "months": [{"key": "2026-05", "count": transaction_count}],
        },
        "transactions": [
            {
                "id": f"transaction-{index}",
                "description": f"Very long merchant transaction {index} " + ("x" * 150),
                "amount": 10 + index,
                "category": "Food",
            }
            for index in range(transaction_count)
        ],
    }


def _memory(
    memory_id: str,
    memory_type: str,
    content: str,
    *,
    importance: int = 3,
    updated_at: str = "2026-05-10T00:00:00Z",
) -> dict:
    return {
        "id": memory_id,
        "memory_type": memory_type,
        "content": content,
        "importance": importance,
        "updated_at": updated_at,
    }


def _plan(plan_id: str, title: str) -> dict:
    return {"id": plan_id, "title": title, "priority": 4, "status": "active"}


def _milestone(milestone_id: str, title: str) -> dict:
    return {"id": milestone_id, "title": title, "priority": 4, "status": "open"}


def _commitment(commitment_id: str, title: str) -> dict:
    return {"id": commitment_id, "title": title, "priority": 4, "status": "open"}

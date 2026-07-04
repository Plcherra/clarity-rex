from typing import Any, Optional

from app.services.accountability_budget_risk import (
    detect_budget_risk_signals,
    financial_budget_performance,
)
from app.services.accountability_pattern_detector import detect_repeated_patterns
from app.services.accountability_plan_drift import detect_plan_signals
from app.services.accountability_rule_risk import detect_rule_violations
from app.services.accountability_shared import current_time
from app.models.accountability import AccountabilityContext, AccountabilitySignal


class AccountabilityService:
    async def analyze_signals(
        self,
        *,
        message: str,
        time_context: Optional[dict[str, Any]] = None,
        personal_rules: Optional[list[dict]] = None,
        plans: Optional[list[dict]] = None,
        plan_milestones: Optional[list[dict]] = None,
        entity_events: Optional[list[dict]] = None,
        relevant_memories: Optional[list[dict]] = None,
        budget_performance: Optional[dict[str, Any]] = None,
    ) -> list[AccountabilitySignal]:
        context = await self.analyze(
            message=message,
            time_context=time_context,
            personal_rules=personal_rules,
            plans=plans,
            plan_milestones=plan_milestones,
            entity_events=entity_events,
            relevant_memories=relevant_memories,
            budget_performance=budget_performance,
        )
        return context.signals

    async def analyze(
        self,
        *,
        message: str,
        time_context: Optional[dict[str, Any]] = None,
        personal_rules: Optional[list[dict]] = None,
        plans: Optional[list[dict]] = None,
        plan_milestones: Optional[list[dict]] = None,
        entity_events: Optional[list[dict]] = None,
        relevant_memories: Optional[list[dict]] = None,
        budget_performance: Optional[dict[str, Any]] = None,
    ) -> AccountabilityContext:
        now = current_time(time_context)
        normalized_rules = personal_rules or []
        normalized_plans = plans or []
        normalized_milestones = plan_milestones or []
        normalized_events = entity_events or []
        normalized_memories = relevant_memories or []

        signals = [
            *detect_rule_violations(message, normalized_rules),
            *detect_plan_signals(
                message=message,
                plans=normalized_plans,
                plan_milestones=normalized_milestones,
                current_time=now,
            ),
            *detect_repeated_patterns(
                message=message,
                entity_events=normalized_events,
                relevant_memories=normalized_memories,
                current_time=now,
            ),
            *detect_budget_risk_signals(budget_performance),
        ]

        return AccountabilityContext(
            signals=signals,
            metadata={
                "message_character_count": len(message),
                "time_context_present": bool(time_context),
                "personal_rule_count": len(normalized_rules),
                "plan_count": len(normalized_plans),
                "plan_milestone_count": len(normalized_milestones),
                "entity_event_count": len(normalized_events),
                "relevant_memory_count": len(normalized_memories),
                "budget_performance_present": bool(budget_performance),
            },
        )

    def active_signals(
        self,
        signals: list[AccountabilitySignal],
    ) -> list[AccountabilitySignal]:
        return [signal for signal in signals if signal.status == "active"]

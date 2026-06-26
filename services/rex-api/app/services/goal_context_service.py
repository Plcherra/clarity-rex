import re
from typing import Any, Awaitable, Callable, Optional

from app.services.accountability_snapshot import (
    active_plans_for,
    open_commitments_for,
)


GOAL_CONTEXT_LIMIT = 12
GOAL_RELATED_MILESTONE_LIMIT = 40
GOAL_PROGRESS_TERMS = (
    "accountability",
    "behind",
    "commitment",
    "commitments",
    "deadline",
    "deadlines",
    "goal",
    "goals",
    "milestone",
    "milestones",
    "on track",
    "plan",
    "plans",
    "progress",
    "target",
    "targets",
)
GOAL_PROGRESS_PATTERNS = (
    re.compile(r"\bhow\s+am\s+i\s+doing\b", re.IGNORECASE),
    re.compile(r"\bhow\s+(are|is)\s+my\s+(goals?|plans?)\b", re.IGNORECASE),
    re.compile(r"\bwhat\s+should\s+i\s+focus\s+on\b", re.IGNORECASE),
    re.compile(
        r"\bwhat\s+(?:goals?|commitments?|plans?)\s+do\s+(?:we|i)\s+have\b",
        re.IGNORECASE,
    ),
    re.compile(
        r"\b(?:list|show|tell me)\s+(?:me\s+)?(?:my|our)\s+"
        r"(?:saved\s+)?(?:goals?|commitments?|plans?)\b",
        re.IGNORECASE,
    ),
)


class GoalContextService:
    async def fetch_goal_context(self, memory_service: Any, message: str) -> dict:
        if not self.is_goal_progress_query(message):
            return {}

        plans = active_plans_for(
            await self._call_list(
                memory_service,
                "list_plans",
                active=True,
                status="active",
                limit=GOAL_CONTEXT_LIMIT,
            )
        )
        milestones = await self._call_list(
            memory_service,
            "list_plan_milestones",
            active=True,
            limit=GOAL_RELATED_MILESTONE_LIMIT,
        )
        commitments = open_commitments_for(
            await self._call_list(
                memory_service,
                "list_commitments",
                active=True,
                limit=GOAL_RELATED_MILESTONE_LIMIT,
            )
        )

        plan_ids = {str(plan.get("id")) for plan in plans if plan.get("id")}
        related_milestones = [
            milestone
            for milestone in milestones
            if not plan_ids or str(milestone.get("plan_id") or "") in plan_ids
        ]
        related_commitments = [
            commitment
            for commitment in commitments
            if self._is_related_commitment(commitment, plan_ids)
        ]

        return {
            "plans": self._with_relevance(plans[:GOAL_CONTEXT_LIMIT]),
            "plan_milestones": self._with_relevance(
                related_milestones[:GOAL_CONTEXT_LIMIT]
            ),
            "commitments": self._with_relevance(
                related_commitments[:GOAL_CONTEXT_LIMIT]
            ),
            "goal_context": {
                "source": "active_goal_context",
                "reason": "User asked about goals, progress, plans, or accountability.",
                "active_plan_count": len(plans),
                "related_milestone_count": len(related_milestones),
                "related_commitment_count": len(related_commitments),
            },
        }

    def is_goal_progress_query(self, message: str) -> bool:
        if any(pattern.search(message) for pattern in GOAL_PROGRESS_PATTERNS):
            return True
        return any(
            re.search(rf"\b{re.escape(term)}\b", message, re.IGNORECASE)
            for term in GOAL_PROGRESS_TERMS
        )

    def merge_structured_context(self, base: dict, goal_context: dict) -> dict:
        if not goal_context:
            return base

        merged = {**base}
        for key in ("plans", "plan_milestones", "commitments"):
            merged[key] = self._merge_records(
                base.get(key) or [],
                goal_context.get(key) or [],
            )
        if goal_context.get("goal_context"):
            merged["goal_context"] = goal_context["goal_context"]
        return merged

    async def _call_list(
        self,
        memory_service: Any,
        method_name: str,
        **kwargs: Any,
    ) -> list[dict]:
        method: Optional[Callable[..., Awaitable[list[dict]]]] = getattr(
            memory_service,
            method_name,
            None,
        )
        if method is None:
            return []
        try:
            rows = await method(**kwargs)
        except TypeError:
            kwargs.pop("status", None)
            try:
                rows = await method(**kwargs)
            except Exception:
                return []
        except Exception:
            return []
        return rows if isinstance(rows, list) else []

    def _is_related_commitment(
        self,
        commitment: dict,
        plan_ids: set[str],
    ) -> bool:
        plan_id = str(commitment.get("plan_id") or "").strip()
        if not plan_id:
            return True
        return not plan_ids or plan_id in plan_ids

    def _with_relevance(self, records: list[dict]) -> list[dict]:
        return [
            {
                **record,
                "relevance_reason": record.get("relevance_reason")
                or "Included because the user asked about goals or progress.",
            }
            for record in records
            if isinstance(record, dict)
        ]

    def _merge_records(self, primary: list[dict], fallback: list[dict]) -> list[dict]:
        merged: list[dict] = []
        seen_ids: set[str] = set()
        for record in [*primary, *fallback]:
            record_id = str(record.get("id") or "")
            if record_id and record_id in seen_ids:
                continue
            if record_id:
                seen_ids.add(record_id)
            merged.append(record)
        return merged

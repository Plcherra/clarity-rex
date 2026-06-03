from __future__ import annotations

from typing import Any, Optional

from app.models.memory_discipline import MemoryDisciplineAction
from app.services.plan_intelligence_models import (
    DESCRIPTION_MIN_TOKENS,
    MAX_AUTO_TOP_LEVEL_PLANS,
    PARENT_PLAN_THRESHOLD,
    RELATED_MILESTONE_THRESHOLD,
    TOP_LEVEL_MINIMUM_SPECIFICITY,
    MilestoneClassification,
    PlanDescriptionQuality,
    PlanIntelligenceDecision,
)
from app.services.plan_intelligence_payloads import (
    build_commitment_from_small_step as build_commitment_payload,
    build_entity_event_from_plan_candidate as build_entity_event_payload,
    build_milestone_from_plan_candidate as build_milestone_payload,
    build_plan_description_update as build_plan_update_payload,
)
from app.services.plan_intelligence_rules import (
    best_milestone_for_commitment,
    duplicate_milestone,
    has_standalone_anchor,
    has_strategy_signal,
    has_success_signal,
    has_timeline_or_target,
    is_badge_like_achievement,
    is_dating_logistics,
    is_first_million_exploration,
    is_historical_context,
    is_small_step,
    parent_plan_score,
    specificity_score,
    titles_equivalent,
)
from app.services.plan_intelligence_text import (
    candidate_text,
    clean,
    context_records,
    join_parts,
    records_from_related,
    record_text,
    route_metadata,
    similarity,
    tokens,
)


class PlanIntelligenceService:
    """Routes plan-like candidates into a stable hierarchy."""

    def classify_plan_candidate(
        self,
        candidate: dict[str, Any],
        context: Any,
    ) -> PlanIntelligenceDecision:
        active_plans = context_records(context, "active_plans")
        if not active_plans:
            active_plans = records_from_related(context, "related_plans")
        active_milestones = context_records(context, "active_milestones")
        if not active_milestones:
            active_milestones = records_from_related(context, "related_milestones")

        if is_first_million_exploration(candidate_text(candidate)):
            return PlanIntelligenceDecision(
                action=MemoryDisciplineAction.IGNORE_NOISY_CANDIDATE,
                payload=candidate,
                reason="Exploratory first-million discussion is not an active plan or milestone.",
                confidence=0.86,
                metadata=route_metadata("first_million_exploration_ignored", 0),
            )

        parent_plan, parent_score = self.find_best_parent_plan(
            candidate,
            active_plans,
        )
        if parent_plan:
            return self._decision_for_parent_plan(
                candidate=candidate,
                parent_plan=parent_plan,
                parent_score=parent_score,
                active_milestones=active_milestones,
            )

        if self.should_create_top_level_plan(candidate, context):
            return PlanIntelligenceDecision(
                action=MemoryDisciplineAction.CREATE_PLAN,
                payload=candidate,
                reason="Candidate is durable and distinct enough to become a top-level plan.",
                confidence=0.72,
                metadata=route_metadata("new_top_level_plan", 0),
            )

        return PlanIntelligenceDecision(
            action=MemoryDisciplineAction.ASK_CONFIRMATION,
            payload=candidate,
            reason="Candidate is plan-like but not specific or durable enough to safely create as a top-level plan.",
            confidence=0.56,
            requires_confirmation=True,
            metadata=route_metadata("ambiguous_plan_candidate", 0),
        )

    def find_best_parent_plan(
        self,
        candidate: dict[str, Any],
        active_plans: list[dict[str, Any]],
    ) -> tuple[Optional[dict[str, Any]], float]:
        scored = [
            (plan, parent_plan_score(candidate, plan))
            for plan in active_plans
            if plan.get("active", True)
            and str(plan.get("status") or "active") in {"active", "in_progress"}
        ]
        if not scored:
            return None, 0
        best_plan, best_score = max(scored, key=lambda item: item[1])
        if best_score < PARENT_PLAN_THRESHOLD:
            return None, best_score
        return best_plan, best_score

    def find_related_milestone(
        self,
        candidate: dict[str, Any],
        active_milestones: list[dict[str, Any]],
    ) -> tuple[Optional[dict[str, Any]], float]:
        scored = [
            (milestone, similarity(candidate_text(candidate), record_text(milestone)))
            for milestone in active_milestones
            if milestone.get("active", True)
            and str(milestone.get("status") or "open") in {"open", "in_progress"}
        ]
        if not scored:
            return None, 0
        best_milestone, best_score = max(scored, key=lambda item: item[1])
        if best_score < RELATED_MILESTONE_THRESHOLD:
            return None, best_score
        return best_milestone, best_score

    def should_create_top_level_plan(
        self,
        candidate: dict[str, Any],
        context: Any,
    ) -> bool:
        active_plans = context_records(context, "active_plans")
        parent_plan, _ = self.find_best_parent_plan(candidate, active_plans)
        if parent_plan:
            return False
        if not active_plans and has_standalone_anchor(candidate):
            return (
                self.validate_plan_description(candidate).passed
                and specificity_score(candidate, small_step_penalty=False) >= 0.38
            )
        if len(active_plans) >= MAX_AUTO_TOP_LEVEL_PLANS:
            return False
        if is_small_step(candidate):
            return False
        if not self.validate_plan_description(candidate).passed:
            return False
        return specificity_score(candidate) >= TOP_LEVEL_MINIMUM_SPECIFICITY

    def validate_plan_description(
        self,
        candidate: dict[str, Any],
    ) -> PlanDescriptionQuality:
        description = clean(candidate.get("description"))
        desired = clean(candidate.get("desired_outcome"))
        combined = join_parts(description, desired)
        current_tokens = tokens(combined)
        score = min(len(current_tokens) / DESCRIPTION_MIN_TOKENS, 0.65)
        if has_strategy_signal(combined):
            score += 0.16
        if has_success_signal(combined):
            score += 0.16
        if has_timeline_or_target(combined):
            score += 0.12
        score = min(score, 1.0)
        if len(current_tokens) < DESCRIPTION_MIN_TOKENS:
            return PlanDescriptionQuality(
                passed=False,
                reason="Top-level plan description is too thin.",
                score=score,
            )
        if not (has_strategy_signal(combined) or has_success_signal(combined)):
            return PlanDescriptionQuality(
                passed=False,
                reason="Top-level plan description needs strategy or success criteria.",
                score=score,
            )
        return PlanDescriptionQuality(
            passed=True,
            reason="Top-level plan description is specific enough.",
            score=score,
        )

    def classify_milestone_candidate(
        self,
        candidate: dict[str, Any],
        parent_plan: dict[str, Any],
        active_milestones: list[dict[str, Any]],
    ) -> MilestoneClassification:
        current_candidate_text = candidate_text(candidate)
        title = clean(candidate.get("title"))
        parent_title = clean(parent_plan.get("title"))

        existing = duplicate_milestone(candidate, active_milestones)
        if existing:
            return MilestoneClassification(
                kind="duplicate",
                reason="Candidate duplicates an existing open milestone.",
                confidence=0.94,
                existing_milestone_id=str(existing.get("id")),
            )

        if titles_equivalent(title, parent_title):
            return MilestoneClassification(
                kind="strategy_description_update",
                reason="Candidate repeats the parent plan title.",
                confidence=0.9,
            )

        if is_first_million_exploration(current_candidate_text):
            return MilestoneClassification(
                kind="noisy_ignore",
                reason="Exploratory first-million discussion is not an active milestone.",
                confidence=0.86,
            )

        if is_dating_logistics(candidate, parent_plan) or is_small_step(candidate):
            return MilestoneClassification(
                kind="task",
                reason="Candidate is a concrete next action.",
                confidence=0.84,
            )

        if is_historical_context(current_candidate_text):
            return MilestoneClassification(
                kind="entity_event",
                reason="Candidate is historical context better stored as an entity event or plan note.",
                confidence=0.76,
            )

        if is_badge_like_achievement(candidate):
            return MilestoneClassification(
                kind="achievement",
                reason="Candidate is a measurable or completable achievement checkpoint.",
                confidence=0.82,
            )

        return MilestoneClassification(
            kind="strategy_description_update",
            reason="Candidate is broad strategy/context rather than a badge-like milestone.",
            confidence=0.74,
        )

    def build_milestone_from_plan_candidate(
        self,
        candidate: dict[str, Any],
        parent_plan: dict[str, Any],
        *,
        existing_milestone: Optional[dict[str, Any]] = None,
    ) -> dict[str, Any]:
        return build_milestone_payload(
            candidate,
            parent_plan,
            existing_milestone=existing_milestone,
        )

    def build_commitment_from_small_step(
        self,
        candidate: dict[str, Any],
        parent_plan: dict[str, Any],
        milestone: Optional[dict[str, Any]] = None,
    ) -> dict[str, Any]:
        return build_commitment_payload(candidate, parent_plan, milestone)

    def build_plan_description_update(
        self,
        candidate: dict[str, Any],
        parent_plan: dict[str, Any],
    ) -> dict[str, Any]:
        return build_plan_update_payload(candidate, parent_plan)

    def build_entity_event_from_plan_candidate(
        self,
        candidate: dict[str, Any],
        parent_plan: dict[str, Any],
    ) -> dict[str, Any]:
        return build_entity_event_payload(candidate, parent_plan)

    def _decision_for_parent_plan(
        self,
        *,
        candidate: dict[str, Any],
        parent_plan: dict[str, Any],
        parent_score: float,
        active_milestones: list[dict[str, Any]],
    ) -> PlanIntelligenceDecision:
        milestones_for_parent = [
            milestone
            for milestone in active_milestones
            if milestone.get("plan_id") == parent_plan.get("id")
        ]
        classification = self.classify_milestone_candidate(
            candidate,
            parent_plan,
            milestones_for_parent,
        )
        if classification.existing_milestone_id:
            return self._update_existing_milestone_decision(
                candidate,
                parent_plan,
                parent_score,
                milestones_for_parent,
                classification,
            )
        if classification.kind == "task" or is_small_step(candidate):
            return self._small_step_decision(
                candidate,
                parent_plan,
                parent_score,
                milestones_for_parent,
                classification,
            )
        if classification.kind in {"strategy_description_update", "entity_event"}:
            return self._context_update_decision(
                candidate,
                parent_plan,
                parent_score,
                classification,
            )
        if classification.kind == "noisy_ignore":
            return PlanIntelligenceDecision(
                action=MemoryDisciplineAction.IGNORE_NOISY_CANDIDATE,
                payload=candidate,
                reason=classification.reason,
                confidence=classification.confidence,
                parent_plan_id=str(parent_plan.get("id")),
                metadata={
                    **route_metadata("noisy_plan_detail_ignored", parent_score),
                    "milestone_classification": classification.model_dump(),
                },
            )
        return self._new_milestone_decision(
            candidate,
            parent_plan,
            parent_score,
            classification,
        )

    def _update_existing_milestone_decision(
        self,
        candidate: dict[str, Any],
        parent_plan: dict[str, Any],
        parent_score: float,
        milestones: list[dict[str, Any]],
        classification: MilestoneClassification,
    ) -> PlanIntelligenceDecision:
        related_milestone = next(
            (
                milestone
                for milestone in milestones
                if str(milestone.get("id")) == classification.existing_milestone_id
            ),
            None,
        )
        if related_milestone is None:
            related_milestone, _ = self.find_related_milestone(candidate, milestones)
        return PlanIntelligenceDecision(
            action=MemoryDisciplineAction.UPDATE_MILESTONE,
            payload=self.build_milestone_from_plan_candidate(
                candidate,
                parent_plan,
                existing_milestone=related_milestone,
            ),
            reason="Plan candidate updates an existing milestone under an active parent plan.",
            confidence=classification.confidence,
            parent_plan_id=str(parent_plan.get("id")),
            target_milestone_id=str(related_milestone.get("id"))
            if related_milestone
            else None,
            metadata={
                **route_metadata("update_related_milestone", parent_score),
                "milestone_classification": classification.model_dump(),
            },
        )

    def _small_step_decision(
        self,
        candidate: dict[str, Any],
        parent_plan: dict[str, Any],
        parent_score: float,
        milestones: list[dict[str, Any]],
        classification: MilestoneClassification,
    ) -> PlanIntelligenceDecision:
        milestone = best_milestone_for_commitment(candidate, milestones)
        return PlanIntelligenceDecision(
            action=MemoryDisciplineAction.CREATE_COMMITMENT,
            payload=self.build_commitment_from_small_step(
                candidate,
                parent_plan,
                milestone=milestone,
            ),
            reason="Plan candidate is a concrete next action, so it belongs as a commitment under the active parent plan.",
            confidence=max(parent_score, 0.76),
            parent_plan_id=str(parent_plan.get("id")),
            target_milestone_id=str(milestone.get("id")) if milestone else None,
            metadata={
                **route_metadata("small_step_to_commitment", parent_score),
                "milestone_classification": classification.model_dump(),
            },
        )

    def _context_update_decision(
        self,
        candidate: dict[str, Any],
        parent_plan: dict[str, Any],
        parent_score: float,
        classification: MilestoneClassification,
    ) -> PlanIntelligenceDecision:
        if classification.kind == "entity_event" and _has_entity_anchor(candidate):
            return PlanIntelligenceDecision(
                action=MemoryDisciplineAction.CREATE_ENTITY_EVENT,
                payload=self.build_entity_event_from_plan_candidate(candidate, parent_plan),
                reason="Plan candidate is historical relationship context, so it belongs as an entity event.",
                confidence=max(parent_score, classification.confidence),
                parent_plan_id=str(parent_plan.get("id")),
                metadata={
                    **route_metadata("plan_detail_to_entity_event", parent_score),
                    "milestone_classification": classification.model_dump(),
                },
            )
        return PlanIntelligenceDecision(
            action=MemoryDisciplineAction.UPDATE_PLAN,
            payload=self.build_plan_description_update(candidate, parent_plan),
            reason="Plan candidate is strategy/context, so it should enrich the parent plan description instead of becoming another milestone.",
            confidence=max(parent_score, classification.confidence),
            parent_plan_id=str(parent_plan.get("id")),
            metadata={
                **route_metadata("plan_detail_to_description", parent_score),
                "milestone_classification": classification.model_dump(),
            },
        )

    def _new_milestone_decision(
        self,
        candidate: dict[str, Any],
        parent_plan: dict[str, Any],
        parent_score: float,
        classification: MilestoneClassification,
    ) -> PlanIntelligenceDecision:
        return PlanIntelligenceDecision(
            action=MemoryDisciplineAction.CREATE_MILESTONE,
            payload=self.build_milestone_from_plan_candidate(candidate, parent_plan),
            reason="Plan candidate is a badge-like achievement under an existing active top-level plan.",
            confidence=max(parent_score, 0.74),
            parent_plan_id=str(parent_plan.get("id")),
            metadata={
                **route_metadata("related_plan_to_milestone", parent_score),
                "milestone_classification": classification.model_dump(),
            },
        )


def _has_entity_anchor(candidate: dict[str, Any]) -> bool:
    return bool(
        candidate.get("primary_entity_id")
        or candidate.get("entity_id")
        or candidate.get("entity_name")
    )

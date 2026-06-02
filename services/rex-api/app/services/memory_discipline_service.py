from __future__ import annotations

from typing import Any, Optional

from app.models.memory_discipline import (
    MemoryCandidateKind,
    MemoryDisciplineAction,
    MemoryDisciplineCandidate,
    MemoryDisciplineContext,
    MemoryDisciplineDecision,
    MemoryRelatedRecord,
)
from app.services.entity_normalization_service import EntityNormalizationService
from app.services.memory_discipline_decision_applier import (
    MemoryDisciplineDecisionApplier,
)
from app.services.memory_discipline_repository import MemoryDisciplineRepository
from app.services.memory_discipline_similarity import (
    candidate_record_text,
    normalized_similarity_score,
    record_similarity,
    record_title,
    title_similarity_score,
    token_overlap_score,
)
from app.services.plan_intelligence_service import PlanIntelligenceService


DISCIPLINE_VERSION = 1
RELATED_RECORD_LIMIT = 5
RELATED_SCORE_THRESHOLD = 0.28
DUPLICATE_SCORE_THRESHOLD = 0.86


class MemoryDisciplineService:
    """Shared pre-save policy for disciplined structured memory writes.

    Memory discipline policy:
    Before saving structured memory, Rex must check related active memory records
    and decide whether to update, merge, archive, create a milestone/task,
    create a new top-level plan, or ask for confirmation. Creating a new
    top-level plan is the last resort.
    """

    def __init__(
        self,
        memory_service: MemoryDisciplineRepository,
        *,
        scan_limit: int = 100,
    ) -> None:
        self.memory_service = memory_service
        self.scan_limit = scan_limit
        self.entity_normalization_service = EntityNormalizationService()
        self.plan_intelligence_service = PlanIntelligenceService()
        self.decision_applier = MemoryDisciplineDecisionApplier(
            memory_service,
            scan_limit=scan_limit,
            entity_normalization_service=self.entity_normalization_service,
        )

    async def gather_context(
        self,
        candidate: MemoryDisciplineCandidate,
    ) -> MemoryDisciplineContext:
        candidate_text = candidate_record_text(candidate.payload)
        long_term_memories = await self._safe_list(
            "list_long_term_memory",
            active=True,
            limit=self.scan_limit,
        )
        entities = await self._safe_list(
            "list_entities",
            active=True,
            limit=self.scan_limit,
        )
        rules = await self._safe_list(
            "list_personal_rules",
            active=True,
            limit=self.scan_limit,
        )
        plans = await self._safe_list(
            "list_plans",
            active=True,
            limit=self.scan_limit,
        )
        milestones = await self._safe_list(
            "list_plan_milestones",
            active=True,
            limit=self.scan_limit,
        )
        commitments = await self._safe_list(
            "list_commitments",
            active=True,
            limit=self.scan_limit,
        )

        return MemoryDisciplineContext(
            candidate=candidate,
            active_entities=entities,
            active_plans=plans,
            active_milestones=milestones,
            active_commitments=commitments,
            active_rules=rules,
            active_long_term_memories=long_term_memories,
            related_entities=self._related_records(
                candidate,
                candidate_text,
                "entities",
                entities,
            ),
            related_plans=self._related_records(
                candidate,
                candidate_text,
                "plans",
                plans,
            ),
            related_milestones=self._related_records(
                candidate,
                candidate_text,
                "plan_milestones",
                milestones,
            ),
            related_commitments=self._related_records(
                candidate,
                candidate_text,
                "commitments",
                commitments,
            ),
            related_rules=self._related_records(
                candidate,
                candidate_text,
                "personal_rules",
                rules,
            ),
            related_long_term_memories=self._related_records(
                candidate,
                candidate_text,
                "long_term_memory",
                long_term_memories,
            ),
        )

    async def decide(
        self,
        candidate: MemoryDisciplineCandidate,
        context: Optional[MemoryDisciplineContext] = None,
    ) -> MemoryDisciplineDecision:
        context = context or await self.gather_context(candidate)
        candidate_text = candidate_record_text(candidate.payload)
        if not candidate_text:
            return MemoryDisciplineDecision(
                action=MemoryDisciplineAction.IGNORE_NOISY_CANDIDATE,
                candidate_kind=candidate.kind,
                payload=candidate.payload,
                reason="Candidate has no useful searchable content.",
                confidence=0.95,
                metadata=self._decision_metadata(
                    MemoryDisciplineAction.IGNORE_NOISY_CANDIDATE,
                    candidate,
                ),
            )

        same_kind_related = self._same_kind_related(candidate.kind, context)
        duplicate = same_kind_related[0] if same_kind_related else None
        if duplicate and duplicate.score >= DUPLICATE_SCORE_THRESHOLD:
            action = _update_action_for_kind(candidate.kind)
            if action:
                return MemoryDisciplineDecision(
                    action=action,
                    candidate_kind=candidate.kind,
                    payload=candidate.payload,
                    reason="Candidate strongly matches an active existing record.",
                    confidence=duplicate.score,
                    target_table=duplicate.table,
                    target_id=duplicate.id,
                    related_records=[duplicate],
                    metadata=self._decision_metadata(action, candidate),
                )

        if candidate.kind == MemoryCandidateKind.PLAN:
            plan_decision = self.plan_intelligence_service.classify_plan_candidate(
                candidate.payload,
                context,
            )
            if plan_decision.action != MemoryDisciplineAction.CREATE_PLAN:
                return self._decision_from_plan_intelligence(
                    candidate,
                    plan_decision,
                    context,
                )

        if candidate.kind == MemoryCandidateKind.PLAN_MILESTONE:
            milestone_decision = self._decide_milestone_candidate(candidate, context)
            if milestone_decision is not None:
                return milestone_decision

        action = _create_action_for_kind(candidate.kind)
        if action is None:
            return MemoryDisciplineDecision(
                action=MemoryDisciplineAction.ASK_CONFIRMATION,
                candidate_kind=candidate.kind,
                payload=candidate.payload,
                reason="Candidate kind needs a later phase-specific decision.",
                confidence=0.5,
                requires_confirmation=True,
                metadata=self._decision_metadata(
                    MemoryDisciplineAction.ASK_CONFIRMATION,
                    candidate,
                    requires_confirmation=True,
                ),
            )

        return MemoryDisciplineDecision(
            action=action,
            candidate_kind=candidate.kind,
            payload=candidate.payload,
            reason="No duplicate existing record passed the update threshold.",
            confidence=0.7,
            related_records=self._top_related_records(context),
            metadata=self._decision_metadata(action, candidate),
        )

    def _decide_milestone_candidate(
        self,
        candidate: MemoryDisciplineCandidate,
        context: MemoryDisciplineContext,
    ) -> MemoryDisciplineDecision | None:
        parent_plan = next(
            (
                plan
                for plan in context.active_plans
                if str(plan.get("id")) == str(candidate.payload.get("plan_id"))
            ),
            None,
        )
        if parent_plan is None:
            return None
        active_milestones = [
            milestone
            for milestone in context.active_milestones
            if str(milestone.get("plan_id")) == str(parent_plan.get("id"))
        ]
        classification = self.plan_intelligence_service.classify_milestone_candidate(
            candidate.payload,
            parent_plan,
            active_milestones,
        )
        metadata = {
            **self._decision_metadata(
                MemoryDisciplineAction.CREATE_MILESTONE,
                candidate,
            ),
            "milestone_classification": classification.model_dump(),
            "parent_plan_id": parent_plan.get("id"),
        }
        if classification.existing_milestone_id:
            return MemoryDisciplineDecision(
                action=MemoryDisciplineAction.UPDATE_MILESTONE,
                candidate_kind=MemoryCandidateKind.PLAN_MILESTONE,
                payload=candidate.payload,
                reason=classification.reason,
                confidence=classification.confidence,
                target_table="plan_milestones",
                target_id=classification.existing_milestone_id,
                related_records=self._top_related_records(context),
                metadata=metadata,
            )
        if classification.kind == "task":
            plan_decision = self.plan_intelligence_service.classify_plan_candidate(
                {
                    **candidate.payload,
                    "plan_type": parent_plan.get("plan_type"),
                },
                {
                    "active_plans": [parent_plan],
                    "active_milestones": active_milestones,
                },
            )
            if plan_decision.action == MemoryDisciplineAction.CREATE_COMMITMENT:
                return self._decision_from_plan_intelligence(candidate, plan_decision, context)
        if classification.kind in {"strategy_description_update", "entity_event"}:
            plan_decision = self.plan_intelligence_service.classify_plan_candidate(
                {
                    **candidate.payload,
                    "plan_type": parent_plan.get("plan_type"),
                },
                {
                    "active_plans": [parent_plan],
                    "active_milestones": active_milestones,
                },
            )
            if plan_decision.action in {
                MemoryDisciplineAction.UPDATE_PLAN,
                MemoryDisciplineAction.CREATE_ENTITY_EVENT,
            }:
                return self._decision_from_plan_intelligence(candidate, plan_decision, context)
        if classification.kind == "noisy_ignore":
            return MemoryDisciplineDecision(
                action=MemoryDisciplineAction.IGNORE_NOISY_CANDIDATE,
                candidate_kind=MemoryCandidateKind.PLAN_MILESTONE,
                payload=candidate.payload,
                reason=classification.reason,
                confidence=classification.confidence,
                related_records=self._top_related_records(context),
                metadata=metadata,
            )
        return None

    async def apply_decision(self, decision: MemoryDisciplineDecision) -> dict:
        return await self.decision_applier.apply_decision(decision)

    async def _safe_list(self, method_name: str, **kwargs: Any) -> list[dict]:
        method = getattr(self.memory_service, method_name, None)
        if method is None:
            return []
        try:
            return await method(**kwargs)
        except TypeError:
            # Some test fakes use narrower signatures. Phase 1 should not make
            # chat/runtime brittle while the discipline layer is being wired in.
            return await method(limit=kwargs.get("limit", self.scan_limit))
        except Exception:
            return []

    def _related_records(
        self,
        candidate: MemoryDisciplineCandidate,
        candidate_text: str,
        table: str,
        records: list[dict],
    ) -> list[MemoryRelatedRecord]:
        related: list[MemoryRelatedRecord] = []
        for record in records:
            score, reason = record_similarity(candidate, candidate_text, table, record)
            if score < RELATED_SCORE_THRESHOLD:
                continue
            record_id = str(record.get("id") or "")
            if not record_id:
                continue
            related.append(
                MemoryRelatedRecord(
                    table=table,
                    id=record_id,
                    score=score,
                    title=record_title(record),
                    reason=reason,
                    record=record,
                )
            )
        return sorted(related, key=lambda item: item.score, reverse=True)[
            :RELATED_RECORD_LIMIT
        ]

    def _same_kind_related(
        self,
        kind: MemoryCandidateKind,
        context: MemoryDisciplineContext,
    ) -> list[MemoryRelatedRecord]:
        if kind == MemoryCandidateKind.LONG_TERM_MEMORY:
            return context.related_long_term_memories
        if kind == MemoryCandidateKind.ENTITY:
            return context.related_entities
        if kind == MemoryCandidateKind.PERSONAL_RULE:
            return context.related_rules
        if kind == MemoryCandidateKind.PLAN:
            return context.related_plans
        if kind == MemoryCandidateKind.PLAN_MILESTONE:
            return context.related_milestones
        if kind == MemoryCandidateKind.COMMITMENT:
            return context.related_commitments
        return []

    def _top_related_records(
        self,
        context: MemoryDisciplineContext,
    ) -> list[MemoryRelatedRecord]:
        records = [
            *context.related_entities,
            *context.related_plans,
            *context.related_milestones,
            *context.related_commitments,
            *context.related_rules,
            *context.related_long_term_memories,
        ]
        return sorted(records, key=lambda item: item.score, reverse=True)[
            :RELATED_RECORD_LIMIT
        ]

    def _decision_metadata(
        self,
        action: MemoryDisciplineAction,
        candidate: MemoryDisciplineCandidate,
        *,
        requires_confirmation: bool = False,
    ) -> dict[str, Any]:
        return {
            "discipline_version": DISCIPLINE_VERSION,
            "discipline_action": action.value,
            "discipline_reason": "phase_1_foundation",
            "merged_from_id": None,
            "archived_by_correction_id": None,
            "canonical_entity_id": None,
            "source_candidate_kind": candidate.kind.value,
            "requires_confirmation": requires_confirmation,
        }

    def _decision_from_plan_intelligence(
        self,
        candidate: MemoryDisciplineCandidate,
        plan_decision,
        context: MemoryDisciplineContext,
    ) -> MemoryDisciplineDecision:
        action_to_kind = {
            MemoryDisciplineAction.CREATE_ENTITY_EVENT: MemoryCandidateKind.ENTITY_EVENT,
            MemoryDisciplineAction.UPDATE_PLAN: MemoryCandidateKind.PLAN,
            MemoryDisciplineAction.CREATE_MILESTONE: MemoryCandidateKind.PLAN_MILESTONE,
            MemoryDisciplineAction.UPDATE_MILESTONE: MemoryCandidateKind.PLAN_MILESTONE,
            MemoryDisciplineAction.CREATE_COMMITMENT: MemoryCandidateKind.COMMITMENT,
            MemoryDisciplineAction.UPDATE_COMMITMENT: MemoryCandidateKind.COMMITMENT,
            MemoryDisciplineAction.ASK_CONFIRMATION: MemoryCandidateKind.PLAN,
            MemoryDisciplineAction.IGNORE_NOISY_CANDIDATE: candidate.kind,
        }
        target_table = None
        target_id = plan_decision.target_milestone_id
        if plan_decision.action == MemoryDisciplineAction.CREATE_ENTITY_EVENT:
            target_table = "entity_events"
        elif plan_decision.action == MemoryDisciplineAction.UPDATE_PLAN:
            target_table = "plans"
            target_id = plan_decision.parent_plan_id
        elif plan_decision.action in {
            MemoryDisciplineAction.CREATE_MILESTONE,
            MemoryDisciplineAction.UPDATE_MILESTONE,
        }:
            target_table = "plan_milestones"
        elif plan_decision.action in {
            MemoryDisciplineAction.CREATE_COMMITMENT,
            MemoryDisciplineAction.UPDATE_COMMITMENT,
        }:
            target_table = "commitments"

        metadata = {
            **self._decision_metadata(
                plan_decision.action,
                candidate,
                requires_confirmation=plan_decision.requires_confirmation,
            ),
            **plan_decision.metadata,
        }
        if plan_decision.parent_plan_id:
            metadata["parent_plan_id"] = plan_decision.parent_plan_id
        if plan_decision.target_milestone_id:
            metadata["target_milestone_id"] = plan_decision.target_milestone_id

        related_records = self._top_related_records(context)
        return MemoryDisciplineDecision(
            action=plan_decision.action,
            candidate_kind=action_to_kind.get(plan_decision.action, candidate.kind),
            payload=plan_decision.payload,
            reason=plan_decision.reason,
            confidence=plan_decision.confidence,
            target_table=target_table,
            target_id=target_id,
            requires_confirmation=plan_decision.requires_confirmation,
            related_records=related_records,
            metadata=metadata,
        )

def _create_action_for_kind(
    kind: MemoryCandidateKind,
) -> MemoryDisciplineAction | None:
    return {
        MemoryCandidateKind.ENTITY: MemoryDisciplineAction.CREATE_ENTITY,
        MemoryCandidateKind.ENTITY_EVENT: MemoryDisciplineAction.CREATE_ENTITY_EVENT,
        MemoryCandidateKind.PERSONAL_RULE: MemoryDisciplineAction.CREATE_RULE,
        MemoryCandidateKind.PLAN: MemoryDisciplineAction.CREATE_PLAN,
        MemoryCandidateKind.PLAN_MILESTONE: MemoryDisciplineAction.CREATE_MILESTONE,
        MemoryCandidateKind.COMMITMENT: MemoryDisciplineAction.CREATE_COMMITMENT,
    }.get(kind)


def _update_action_for_kind(
    kind: MemoryCandidateKind,
) -> MemoryDisciplineAction | None:
    return {
        MemoryCandidateKind.ENTITY: MemoryDisciplineAction.UPDATE_ENTITY,
        MemoryCandidateKind.PERSONAL_RULE: MemoryDisciplineAction.UPDATE_RULE,
        MemoryCandidateKind.PLAN: MemoryDisciplineAction.UPDATE_PLAN,
        MemoryCandidateKind.PLAN_MILESTONE: MemoryDisciplineAction.UPDATE_MILESTONE,
        MemoryCandidateKind.COMMITMENT: MemoryDisciplineAction.UPDATE_COMMITMENT,
    }.get(kind)

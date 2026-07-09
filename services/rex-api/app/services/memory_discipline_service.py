from __future__ import annotations

from typing import Any, Optional

from app.models.memory_discipline import (
    MemoryRecordKind,
    MemoryDisciplineAction,
    MemoryDisciplineCandidate,
    MemoryDisciplineContext,
    MemoryDisciplineDecision,
    MemoryRelatedRecord,
)
from app.services.entity_normalization_service import EntityNormalizationService
from app.services.memory_discipline_confirmed_writes import (
    is_confirmed_plan_service_write,
    is_confirmed_service_write,
)
from app.services.memory_discipline_decision_applier import (
    MemoryDisciplineDecisionApplier,
)
from app.services.memory_discipline_list_loader import safe_discipline_list
from app.services.memory_discipline_repository import MemoryDisciplineRepository
from app.services.memory_discipline_decision_factory import (
    MemoryDisciplineDecisionFactoryMixin,
    create_action_for_kind,
    update_action_for_kind,
)
from app.services.plan_intelligence_service import PlanIntelligenceService
from app.services.memory_discipline_similarity import (
    candidate_record_text,
    normalized_similarity_score,
    record_similarity,
    record_title,
    title_similarity_score,
    token_overlap_score,
)


DISCIPLINE_VERSION = 1
RELATED_RECORD_LIMIT = 5
RELATED_SCORE_THRESHOLD = 0.28
DUPLICATE_SCORE_THRESHOLD = 0.86


class MemoryDisciplineService(MemoryDisciplineDecisionFactoryMixin):
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
        long_term_memories = await safe_discipline_list(
            self.memory_service,
            "list_long_term_memory",
            scan_limit=self.scan_limit,
            active=True,
            limit=self.scan_limit,
        )
        entities = await safe_discipline_list(
            self.memory_service,
            "list_entities",
            scan_limit=self.scan_limit,
            active=True,
            limit=self.scan_limit,
        )
        rules = await safe_discipline_list(
            self.memory_service,
            "list_personal_rules",
            scan_limit=self.scan_limit,
            active=True,
            limit=self.scan_limit,
        )
        plans = await safe_discipline_list(
            self.memory_service,
            "list_plans",
            scan_limit=self.scan_limit,
            active=True,
            limit=self.scan_limit,
        )
        milestones = await safe_discipline_list(
            self.memory_service,
            "list_plan_milestones",
            scan_limit=self.scan_limit,
            active=True,
            limit=self.scan_limit,
        )

        return MemoryDisciplineContext(
            candidate=candidate,
            active_entities=entities,
            active_plans=plans,
            active_milestones=milestones,
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
            return self._empty_candidate_decision(candidate)

        same_kind_related = self._same_kind_related(candidate.kind, context)
        duplicate = same_kind_related[0] if same_kind_related else None
        if duplicate and duplicate.score >= DUPLICATE_SCORE_THRESHOLD:
            action = update_action_for_kind(candidate.kind)
            if action and not is_confirmed_service_write(candidate.payload):
                return self._duplicate_update_decision(candidate, duplicate, action)

        if candidate.kind == MemoryRecordKind.PLAN:
            if not is_confirmed_plan_service_write(candidate.payload):
                plan_decision = self.plan_intelligence_service.classify_plan_candidate(
                    candidate.payload,
                    context,
                )
                if plan_decision.action == MemoryDisciplineAction.IGNORE_NOISY_CANDIDATE:
                    return self._decision_from_plan_intelligence(
                        candidate,
                        plan_decision,
                        context,
                    )
                if plan_decision.action != MemoryDisciplineAction.CREATE_PLAN:
                    return self._decision_from_plan_intelligence(
                        candidate,
                        plan_decision,
                        context,
                    )

        if candidate.kind == MemoryRecordKind.PLAN_MILESTONE:
            milestone_decision = self._decide_milestone_candidate(candidate, context)
            if milestone_decision is not None:
                return milestone_decision

        action = create_action_for_kind(candidate.kind)
        if action is None:
            return MemoryDisciplineDecision(
                action=MemoryDisciplineAction.ASK_CONFIRMATION,
                record_kind=candidate.kind,
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
            record_kind=candidate.kind,
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
                record_kind=MemoryRecordKind.PLAN_MILESTONE,
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
            if plan_decision.action == MemoryDisciplineAction.CREATE_MILESTONE:
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
                record_kind=MemoryRecordKind.PLAN_MILESTONE,
                payload=candidate.payload,
                reason=classification.reason,
                confidence=classification.confidence,
                related_records=self._top_related_records(context),
                metadata=metadata,
            )
        return None

    async def apply_decision(self, decision: MemoryDisciplineDecision) -> dict:
        return await self.decision_applier.apply_decision(decision)

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
        kind: MemoryRecordKind,
        context: MemoryDisciplineContext,
    ) -> list[MemoryRelatedRecord]:
        if kind == MemoryRecordKind.LONG_TERM_MEMORY:
            return context.related_long_term_memories
        if kind == MemoryRecordKind.ENTITY:
            return context.related_entities
        if kind == MemoryRecordKind.PERSONAL_RULE:
            return context.related_rules
        if kind == MemoryRecordKind.PLAN:
            return context.related_plans
        if kind == MemoryRecordKind.PLAN_MILESTONE:
            return context.related_milestones
        return []

    def _top_related_records(
        self,
        context: MemoryDisciplineContext,
    ) -> list[MemoryRelatedRecord]:
        records = [
            *context.related_entities,
            *context.related_plans,
            *context.related_milestones,
            *context.related_rules,
            *context.related_long_term_memories,
        ]
        return sorted(records, key=lambda item: item.score, reverse=True)[
            :RELATED_RECORD_LIMIT
        ]

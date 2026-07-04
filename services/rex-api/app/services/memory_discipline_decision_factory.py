from __future__ import annotations

from typing import Any

from app.models.memory_discipline import (
    MemoryDisciplineAction,
    MemoryDisciplineCandidate,
    MemoryDisciplineContext,
    MemoryDisciplineDecision,
    MemoryRecordKind,
    MemoryRelatedRecord,
)


DISCIPLINE_VERSION = 1


def create_action_for_kind(
    kind: MemoryRecordKind,
) -> MemoryDisciplineAction | None:
    return {
        MemoryRecordKind.ENTITY: MemoryDisciplineAction.CREATE_ENTITY,
        MemoryRecordKind.ENTITY_EVENT: MemoryDisciplineAction.CREATE_ENTITY_EVENT,
        MemoryRecordKind.PERSONAL_RULE: MemoryDisciplineAction.CREATE_RULE,
        MemoryRecordKind.PLAN: MemoryDisciplineAction.CREATE_PLAN,
        MemoryRecordKind.PLAN_MILESTONE: MemoryDisciplineAction.CREATE_MILESTONE,
    }.get(kind)


def update_action_for_kind(
    kind: MemoryRecordKind,
) -> MemoryDisciplineAction | None:
    return {
        MemoryRecordKind.ENTITY: MemoryDisciplineAction.UPDATE_ENTITY,
        MemoryRecordKind.PERSONAL_RULE: MemoryDisciplineAction.UPDATE_RULE,
        MemoryRecordKind.PLAN: MemoryDisciplineAction.UPDATE_PLAN,
        MemoryRecordKind.PLAN_MILESTONE: MemoryDisciplineAction.UPDATE_MILESTONE,
    }.get(kind)


class MemoryDisciplineDecisionFactoryMixin:
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
            "source_record_kind": candidate.kind.value,
            "requires_confirmation": requires_confirmation,
        }

    def _decision_from_plan_intelligence(
        self,
        candidate: MemoryDisciplineCandidate,
        plan_decision,
        context: MemoryDisciplineContext,
    ) -> MemoryDisciplineDecision:
        action_to_kind = {
            MemoryDisciplineAction.CREATE_ENTITY_EVENT: MemoryRecordKind.ENTITY_EVENT,
            MemoryDisciplineAction.UPDATE_PLAN: MemoryRecordKind.PLAN,
            MemoryDisciplineAction.CREATE_MILESTONE: MemoryRecordKind.PLAN_MILESTONE,
            MemoryDisciplineAction.UPDATE_MILESTONE: MemoryRecordKind.PLAN_MILESTONE,
            MemoryDisciplineAction.ASK_CONFIRMATION: MemoryRecordKind.PLAN,
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
            record_kind=action_to_kind.get(plan_decision.action, candidate.kind),
            payload=plan_decision.payload,
            reason=plan_decision.reason,
            confidence=plan_decision.confidence,
            target_table=target_table,
            target_id=target_id,
            requires_confirmation=plan_decision.requires_confirmation,
            related_records=related_records,
            metadata=metadata,
        )

    def _empty_candidate_decision(
        self,
        candidate: MemoryDisciplineCandidate,
    ) -> MemoryDisciplineDecision:
        return MemoryDisciplineDecision(
            action=MemoryDisciplineAction.IGNORE_NOISY_CANDIDATE,
            record_kind=candidate.kind,
            payload=candidate.payload,
            reason="Candidate has no useful searchable content.",
            confidence=0.95,
            metadata=self._decision_metadata(
                MemoryDisciplineAction.IGNORE_NOISY_CANDIDATE,
                candidate,
            ),
        )

    def _duplicate_update_decision(
        self,
        candidate: MemoryDisciplineCandidate,
        duplicate: MemoryRelatedRecord,
        action: MemoryDisciplineAction,
    ) -> MemoryDisciplineDecision:
        return MemoryDisciplineDecision(
            action=action,
            record_kind=candidate.kind,
            payload=candidate.payload,
            reason="Candidate strongly matches an active existing record.",
            confidence=duplicate.score,
            target_table=duplicate.table,
            target_id=duplicate.id,
            related_records=[duplicate],
            metadata=self._decision_metadata(action, candidate),
        )

from __future__ import annotations

from typing import Any

from app.models.memory_discipline import (
    MemoryCandidateKind,
    MemoryDisciplineAction,
    MemoryDisciplineCandidate,
)
from app.services.memory_candidate_preview import clean_optional


class MemoryCandidateApplier:
    def __init__(
        self,
        *,
        memory_service,
        memory_correction_service,
        memory_discipline_service,
    ) -> None:
        self.memory_service = memory_service
        self.memory_correction_service = memory_correction_service
        self.memory_discipline_service = memory_discipline_service

    async def apply_candidate(self, candidate: dict[str, Any]) -> dict[str, Any]:
        candidate_type = str(candidate.get("candidate_type") or "")
        payload = self._payload_with_discipline_metadata(candidate)
        source_conversation_id = candidate.get("source_conversation_id")
        source_message_id = candidate.get("source_message_id")

        if candidate_type == "long_term_memory":
            return await self._apply_long_term_memory(
                payload,
                source_conversation_id=source_conversation_id,
                source_message_id=source_message_id,
            )
        if candidate_type == "entity_event":
            record = await self.memory_service.create_entity_event(payload)
            return {
                "action": "create_entity_event",
                "applied": True,
                "table": "entity_events",
                "record": record,
            }
        if candidate_type == "correction":
            return await self._apply_correction(
                payload,
                source_conversation_id=source_conversation_id,
                source_message_id=source_message_id,
            )
        return await self._apply_structured_candidate(
            candidate_type,
            payload,
            source_conversation_id=source_conversation_id,
            source_message_id=source_message_id,
        )

    def _payload_with_discipline_metadata(self, candidate: dict[str, Any]) -> dict[str, Any]:
        payload = dict(candidate.get("payload") or {})
        discipline_hint = payload.pop("memory_discipline", None)
        if isinstance(discipline_hint, dict):
            payload["metadata"] = {
                **(payload.get("metadata") or {}),
                "memory_discipline": discipline_hint,
            }
        return payload

    async def _apply_long_term_memory(
        self,
        payload: dict[str, Any],
        *,
        source_conversation_id: object,
        source_message_id: object,
    ) -> dict[str, Any]:
        memory_type = str(payload.get("memory_type") or "").strip()
        content = clean_optional(payload.get("content"))
        if not memory_type or not content:
            return {
                "applied": False,
                "reason": "Long-term memory candidate is missing type or content.",
            }
        record = await self.memory_service.save_long_term_memory(
            memory_type=memory_type,
            content=content,
            source_conversation_id=source_conversation_id,
            source_message_id=source_message_id,
            importance=int(payload.get("importance") or 3),
            confidence=float(payload.get("confidence") or 0.75),
            metadata=payload.get("metadata") or {},
        )
        return {
            "action": "create_long_term_memory",
            "applied": True,
            "table": "long_term_memory",
            "record": record,
        }

    async def _apply_correction(
        self,
        payload: dict[str, Any],
        *,
        source_conversation_id: object,
        source_message_id: object,
    ) -> dict[str, Any]:
        text = clean_optional(payload.get("text") or payload.get("content"))
        if not text:
            return {
                "applied": False,
                "reason": "Correction candidate is missing correction text.",
            }
        report = await self.memory_correction_service.apply_correction(
            text,
            source_conversation_id=source_conversation_id,
            source_message_id=source_message_id,
            force=True,
        )
        report_payload = report.as_dict()
        return {
            "action": "apply_correction",
            "applied": bool(report.applied),
            "table": "memory_corrections",
            "record": correction_record(report_payload),
            "correction_report": report_payload,
            "stale_terms": correction_stale_terms(report_payload),
            "reason": (
                None
                if report.applied
                else "Correction did not affect any active records."
            ),
        }

    async def _apply_structured_candidate(
        self,
        candidate_type: str,
        payload: dict[str, Any],
        *,
        source_conversation_id: object,
        source_message_id: object,
    ) -> dict[str, Any]:
        kind = candidate_kind(candidate_type)
        if kind is None:
            return {
                "applied": False,
                "reason": f"Candidate type {candidate_type} is not applyable in Phase 1b.",
            }
        if candidate_type == "plan" and not clean_optional(payload.get("description")):
            return {
                "applied": False,
                "reason": (
                    "Top-level plan candidates need a clear description before "
                    "they can be approved."
                ),
            }

        discipline_candidate = MemoryDisciplineCandidate(
            kind=kind,
            payload=payload,
            source_conversation_id=source_conversation_id,
            source_message_id=source_message_id,
            source_memory_id=payload.get("source_memory_id"),
        )
        decision = await self.memory_discipline_service.decide(discipline_candidate)
        if decision.action == MemoryDisciplineAction.ASK_CONFIRMATION:
            create_action = create_action_for_kind(kind)
            if create_action is None:
                return {
                    "applied": False,
                    "reason": decision.reason,
                    "requires_confirmation": True,
                }
            decision = decision.model_copy(
                update={
                    "action": create_action,
                    "requires_confirmation": False,
                    "reason": (
                        "User explicitly approved the pending memory candidate."
                    ),
                }
            )
        applied = await self.memory_discipline_service.apply_decision(decision)
        return {
            **applied,
            "table": table_for_apply_action(applied.get("action"))
            or table_for_candidate_type(candidate_type),
        }


def candidate_kind(candidate_type: str) -> MemoryCandidateKind | None:
    return {
        "entity": MemoryCandidateKind.ENTITY,
        "entity_event": MemoryCandidateKind.ENTITY_EVENT,
        "personal_rule": MemoryCandidateKind.PERSONAL_RULE,
        "plan": MemoryCandidateKind.PLAN,
        "plan_milestone": MemoryCandidateKind.PLAN_MILESTONE,
        "commitment": MemoryCandidateKind.COMMITMENT,
    }.get(candidate_type)


def create_action_for_kind(kind: MemoryCandidateKind) -> MemoryDisciplineAction | None:
    return {
        MemoryCandidateKind.ENTITY: MemoryDisciplineAction.CREATE_ENTITY,
        MemoryCandidateKind.ENTITY_EVENT: MemoryDisciplineAction.CREATE_ENTITY_EVENT,
        MemoryCandidateKind.PERSONAL_RULE: MemoryDisciplineAction.CREATE_RULE,
        MemoryCandidateKind.PLAN: MemoryDisciplineAction.CREATE_PLAN,
        MemoryCandidateKind.PLAN_MILESTONE: MemoryDisciplineAction.CREATE_MILESTONE,
        MemoryCandidateKind.COMMITMENT: MemoryDisciplineAction.CREATE_COMMITMENT,
    }.get(kind)


def table_for_candidate_type(candidate_type: str) -> str | None:
    return {
        "long_term_memory": "long_term_memory",
        "entity": "entities",
        "entity_event": "entity_events",
        "personal_rule": "personal_rules",
        "plan": "plans",
        "plan_milestone": "plan_milestones",
        "commitment": "commitments",
        "correction": "memory_corrections",
    }.get(candidate_type)


def table_for_apply_action(action: object) -> str | None:
    return {
        "create_entity": "entities",
        "update_entity": "entities",
        "create_entity_event": "entity_events",
        "create_plan": "plans",
        "update_plan": "plans",
        "create_milestone": "plan_milestones",
        "update_milestone": "plan_milestones",
        "create_commitment": "commitments",
        "update_commitment": "commitments",
        "create_rule": "personal_rules",
        "update_rule": "personal_rules",
    }.get(str(action or ""))


def correction_record(report: dict[str, Any]) -> dict[str, Any]:
    corrections = report.get("corrections") or []
    if corrections:
        first = corrections[0]
        return {
            "id": first.get("id"),
            "correction_ids": [
                correction.get("id")
                for correction in corrections
                if correction.get("id") is not None
            ],
        }
    affected = report.get("affected_records") or []
    if affected:
        first = affected[0]
        return {
            "id": f"{first.get('table')}:{first.get('id')}",
            "affected_records": affected,
        }
    return {"id": None}


def correction_stale_terms(report: dict[str, Any]) -> list[str]:
    stale_terms = report.get("verification_stale_terms") or []
    if stale_terms:
        return [
            term
            for term in (clean_optional(stale_term) for stale_term in stale_terms)
            if term
        ]
    intent = report.get("intent") or {}
    old_value = clean_optional(intent.get("old_value"))
    return [old_value] if old_value else []

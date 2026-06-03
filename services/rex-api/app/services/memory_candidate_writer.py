import re
from typing import Any, Optional

from app.models.memory_candidate import MemoryCandidateCreateRequest
from app.models.memory_discipline import (
    MemoryCandidateKind,
    MemoryDisciplineDecision,
)
from app.services.memory_discipline_service import MemoryDisciplineService
from app.services.memory_path_policy import pending_review_metadata
from app.services.memory_structured_candidate_normalizer import clean_text


class MemoryCandidateWriter:
    def __init__(
        self,
        memory_service,
        memory_discipline_service: MemoryDisciplineService,
    ) -> None:
        self.memory_service = memory_service
        self.memory_discipline_service = memory_discipline_service

    async def save_structured_candidate(
        self,
        *,
        kind: MemoryCandidateKind,
        payload: dict,
        rationale: str,
        fallback: Any,
        brain_metadata: Optional[dict[str, Any]] = None,
    ) -> Optional[dict]:
        candidate = self._discipline_candidate(kind, payload)
        try:
            decision = await self.memory_discipline_service.decide(candidate)
        except Exception:
            decision = None

        decision_kind = decision.candidate_kind if decision is not None else kind
        candidate_type = self.candidate_type_for_kind(decision_kind)
        if candidate_type is None:
            return None
        candidate_payload = dict(decision.payload if decision is not None else payload)
        if decision is not None:
            candidate_payload["memory_discipline"] = {
                "action": decision.action.value,
                "reason": decision.reason,
                "confidence": decision.confidence,
                "target_table": decision.target_table,
                "target_id": decision.target_id,
                "requires_confirmation": decision.requires_confirmation,
            }
        return await self.create_pending_memory_candidate(
            candidate_type=candidate_type,
            payload=candidate_payload,
            rationale=rationale,
            conversation_id=str(payload.get("source_conversation_id") or ""),
            user_message_id=clean_text(payload.get("source_message_id")),
            risk_level=self.candidate_risk_level(
                candidate_type=candidate_type,
                payload=candidate_payload,
                decision=decision,
            ),
            brain_metadata=brain_metadata,
        )

    def _discipline_candidate(
        self,
        kind: MemoryCandidateKind,
        payload: dict,
    ):
        from app.models.memory_discipline import MemoryDisciplineCandidate

        return MemoryDisciplineCandidate(
            kind=kind,
            payload=payload,
            source_conversation_id=payload.get("source_conversation_id"),
            source_message_id=payload.get("source_message_id"),
            source_memory_id=payload.get("source_memory_id"),
        )

    def candidate_type_for_kind(self, kind: MemoryCandidateKind) -> Optional[str]:
        return {
            MemoryCandidateKind.ENTITY: "entity",
            MemoryCandidateKind.PERSONAL_RULE: "personal_rule",
            MemoryCandidateKind.PLAN: "plan",
            MemoryCandidateKind.PLAN_MILESTONE: "plan_milestone",
            MemoryCandidateKind.COMMITMENT: "commitment",
        }.get(kind)

    def payload_with_brain_metadata(
        self,
        payload: dict[str, Any],
        *,
        brain_metadata: Optional[dict[str, Any]] = None,
    ) -> dict[str, Any]:
        if not brain_metadata:
            return payload
        updated = dict(payload)
        metadata = updated.get("metadata")
        updated["metadata"] = dict(metadata) if isinstance(metadata, dict) else {}
        updated["metadata"]["rex_brain"] = brain_metadata
        return updated

    async def create_pending_memory_candidate(
        self,
        *,
        candidate_type: str,
        payload: dict[str, Any],
        rationale: str,
        conversation_id: str,
        user_message_id: Optional[str],
        risk_level: str,
        brain_metadata: Optional[dict[str, Any]] = None,
    ) -> Optional[dict]:
        create_candidate = getattr(self.memory_service, "create_memory_candidate", None)
        if create_candidate is None:
            return None
        payload = self.payload_with_review_metadata(
            payload,
            candidate_type=candidate_type,
            risk_level=risk_level,
            rationale=rationale,
        )
        payload = self.payload_with_brain_metadata(
            payload,
            brain_metadata=brain_metadata,
        )
        duplicate = await self.find_pending_duplicate_candidate(
            candidate_type=candidate_type,
            payload=payload,
            conversation_id=conversation_id,
        )
        if duplicate is not None:
            return self.extraction_result(
                payload=payload,
                row=duplicate,
                candidate_type=candidate_type,
                rationale=rationale,
                action="candidate_reused",
            )
        try:
            row = await create_candidate(
                MemoryCandidateCreateRequest(
                    candidate_type=candidate_type,
                    payload=payload,
                    risk_level=risk_level,
                    reason=rationale,
                    source_conversation_id=conversation_id,
                    source_message_id=user_message_id,
                ).model_dump(exclude_none=True)
            )
        except Exception:
            return None
        return self.extraction_result(
            payload=payload,
            row=row,
            candidate_type=candidate_type,
            rationale=rationale,
            action="candidate_created",
        )

    def extraction_result(
        self,
        *,
        payload: dict[str, Any],
        row: dict[str, Any],
        candidate_type: str,
        rationale: str,
        action: str,
    ) -> dict:
        metadata = payload.get("metadata") if isinstance(payload, dict) else {}
        if not isinstance(metadata, dict):
            metadata = {}
        return {
            **payload,
            **row,
            "extraction_kind": "memory_candidate",
            "structured_type": candidate_type
            if candidate_type != "long_term_memory"
            else None,
            "memory_type": payload.get("memory_type")
            if candidate_type == "long_term_memory"
            else None,
            "extraction_action": action,
            "extraction_rationale": rationale,
            "pending": True,
            "memory_path": metadata.get("memory_path") if metadata else None,
            "review_required": metadata.get("review_required") if metadata else True,
            "review_reason": metadata.get("review_reason") if metadata else rationale,
        }

    def payload_with_review_metadata(
        self,
        payload: dict[str, Any],
        *,
        candidate_type: str,
        risk_level: str,
        rationale: str,
    ) -> dict[str, Any]:
        updated = dict(payload)
        metadata = updated.get("metadata")
        updated["metadata"] = pending_review_metadata(
            metadata if isinstance(metadata, dict) else {},
            candidate_type=candidate_type,
            risk_level=risk_level,
            rationale=rationale,
        )
        return updated

    async def find_pending_duplicate_candidate(
        self,
        *,
        candidate_type: str,
        payload: dict[str, Any],
        conversation_id: str,
    ) -> Optional[dict]:
        list_candidates = getattr(self.memory_service, "list_memory_candidates", None)
        if list_candidates is None:
            return None
        try:
            candidates = await list_candidates(
                limit=100,
                candidate_type=candidate_type,
                status="pending",
            )
        except Exception:
            return None

        for candidate in candidates:
            if self.payloads_match(candidate.get("payload") or {}, payload):
                return candidate
        return None

    def payloads_match(self, existing: dict[str, Any], incoming: dict[str, Any]) -> bool:
        existing_fingerprint = self.payload_fingerprint(existing)
        incoming_fingerprint = self.payload_fingerprint(incoming)
        if existing_fingerprint and incoming_fingerprint:
            return existing_fingerprint == incoming_fingerprint
        return self.normalized_payload_text(existing) == self.normalized_payload_text(
            incoming
        )

    def payload_fingerprint(self, payload: dict[str, Any]) -> Optional[str]:
        metadata = payload.get("metadata")
        if not isinstance(metadata, dict):
            return None
        fingerprint = metadata.get("topic_fingerprint")
        return str(fingerprint) if fingerprint else None

    def normalized_payload_text(self, payload: dict[str, Any]) -> str:
        text = " ".join(
            str(payload.get(field) or "")
            for field in ("content", "title", "display_name", "commitment_text")
        )
        normalized = re.sub(r"[^a-z0-9]+", " ", text.lower())
        return re.sub(r"\s+", " ", normalized).strip()

    def candidate_risk_level(
        self,
        *,
        candidate_type: str,
        payload: dict[str, Any],
        decision: Optional[MemoryDisciplineDecision] = None,
    ) -> str:
        if candidate_type in {"plan", "correction", "archive", "merge"}:
            return "high"
        if decision is not None and (
            decision.requires_confirmation
            or decision.target_id
            or decision.action.value.startswith(("archive", "update"))
        ):
            return "high"
        if candidate_type in {"commitment", "entity_event"}:
            return "low"
        if candidate_type == "long_term_memory":
            importance = int(payload.get("importance") or 3)
            return "high" if importance >= 5 else "medium"
        return "medium"

    async def call_service_create(self, method: Any, request: Any) -> Optional[dict]:
        try:
            return await method(request)
        except Exception:
            return None

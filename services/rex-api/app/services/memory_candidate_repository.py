from typing import Optional

from app.services.memory_errors import MemoryServiceError

VALID_MEMORY_CORRECTION_TYPES = {
    "entity_name",
    "entity_relationship",
    "plan_detail",
    "rule_detail",
    "commitment_detail",
    "location",
    "preference",
    "other",
}
VALID_MEMORY_CANDIDATE_TYPES = {
    "long_term_memory",
    "entity",
    "entity_event",
    "personal_rule",
    "plan",
    "plan_milestone",
    "commitment",
    "correction",
    "archive",
    "merge",
}
VALID_MEMORY_CANDIDATE_STATUSES = {
    "pending",
    "approved",
    "rejected",
    "applied",
    "failed",
}
VALID_MEMORY_CANDIDATE_RISK_LEVELS = {"low", "medium", "high"}

MEMORY_CORRECTION_SELECT = (
    "id,correction_type,old_value,new_value,target_table,target_id,"
    "source_conversation_id,source_message_id,applied,confidence,metadata,created_at"
)
MEMORY_CANDIDATE_SELECT = (
    "id,candidate_type,payload,status,risk_level,decision,reason,"
    "source_conversation_id,source_message_id,approved_by,approved_at,applied_at,"
    "rejected_at,applied_record_table,applied_record_id,verification,created_at,"
    "updated_at"
)


class MemoryCandidateRepository:
    def __init__(self, store: object) -> None:
        self.store = store

    async def create_memory_correction(self, correction: dict) -> dict:
        correction_type = correction.get("correction_type")
        if correction_type not in VALID_MEMORY_CORRECTION_TYPES:
            raise MemoryServiceError("Invalid memory correction type.", 400)
        new_value = str(correction.get("new_value") or "").strip()
        if not new_value:
            raise MemoryServiceError("Memory correction new value is required.", 400)

        return await self.store._create_record(
            self.store.settings.supabase_memory_corrections_table,
            {
                "correction_type": correction_type,
                "old_value": correction.get("old_value"),
                "new_value": new_value,
                "target_table": correction.get("target_table"),
                "target_id": correction.get("target_id"),
                "source_conversation_id": correction.get("source_conversation_id"),
                "source_message_id": correction.get("source_message_id"),
                "applied": bool(correction.get("applied", False)),
                "confidence": correction.get("confidence", 0.9),
                "metadata": correction.get("metadata") or {},
            },
            MEMORY_CORRECTION_SELECT,
        )

    async def list_memory_corrections(
        self,
        limit: int = 50,
        correction_type: Optional[str] = None,
        applied: Optional[bool] = None,
        target_table: Optional[str] = None,
        target_id: Optional[str] = None,
    ) -> list[dict]:
        if correction_type is not None and (
            correction_type not in VALID_MEMORY_CORRECTION_TYPES
        ):
            raise MemoryServiceError("Invalid memory correction type.", 400)
        return await self.store._list_records(
            self.store.settings.supabase_memory_corrections_table,
            select=MEMORY_CORRECTION_SELECT,
            filters={
                "correction_type": correction_type,
                "applied": applied,
                "target_table": target_table,
                "target_id": target_id,
            },
            order="created_at.desc",
            limit=limit,
        )

    async def create_memory_candidate(self, candidate: dict) -> dict:
        candidate_type = candidate.get("candidate_type")
        if candidate_type not in VALID_MEMORY_CANDIDATE_TYPES:
            raise MemoryServiceError("Invalid memory candidate type.", 400)
        status = candidate.get("status", "pending")
        if status not in VALID_MEMORY_CANDIDATE_STATUSES:
            raise MemoryServiceError("Invalid memory candidate status.", 400)
        risk_level = candidate.get("risk_level", "medium")
        if risk_level not in VALID_MEMORY_CANDIDATE_RISK_LEVELS:
            raise MemoryServiceError("Invalid memory candidate risk level.", 400)
        payload = candidate.get("payload")
        if not isinstance(payload, dict):
            raise MemoryServiceError("Memory candidate payload must be an object.", 400)

        return await self.store._create_record(
            self.store.settings.supabase_memory_candidates_table,
            {
                "candidate_type": candidate_type,
                "payload": payload,
                "status": status,
                "risk_level": risk_level,
                "decision": candidate.get("decision"),
                "reason": candidate.get("reason"),
                "source_conversation_id": candidate.get("source_conversation_id"),
                "source_message_id": candidate.get("source_message_id"),
                "approved_by": candidate.get("approved_by"),
                "approved_at": candidate.get("approved_at"),
                "applied_at": candidate.get("applied_at"),
                "rejected_at": candidate.get("rejected_at"),
                "applied_record_table": candidate.get("applied_record_table"),
                "applied_record_id": candidate.get("applied_record_id"),
                "verification": candidate.get("verification"),
            },
            MEMORY_CANDIDATE_SELECT,
        )

    async def list_memory_candidates(
        self,
        limit: int = 50,
        candidate_type: Optional[str] = None,
        status: Optional[str] = None,
        risk_level: Optional[str] = None,
        source_conversation_id: Optional[str] = None,
    ) -> list[dict]:
        self.validate_memory_candidate_type(candidate_type)
        self.validate_memory_candidate_status(status)
        self.validate_memory_candidate_risk_level(risk_level)
        return await self.store._list_records(
            self.store.settings.supabase_memory_candidates_table,
            select=MEMORY_CANDIDATE_SELECT,
            filters={
                "candidate_type": candidate_type,
                "status": status,
                "risk_level": risk_level,
                "source_conversation_id": source_conversation_id,
            },
            order="created_at.desc",
            limit=limit,
        )

    async def get_memory_candidate(self, candidate_id: str) -> Optional[dict]:
        rows = await self.store._request(
            "GET",
            self.store.settings.supabase_memory_candidates_table,
            query={
                "id": f"eq.{candidate_id}",
                "select": MEMORY_CANDIDATE_SELECT,
                "limit": "1",
            },
        )
        return rows[0] if rows else None

    async def update_memory_candidate(
        self,
        candidate_id: str,
        **updates: object,
    ) -> Optional[dict]:
        if "candidate_type" in updates:
            self.validate_memory_candidate_type(updates.get("candidate_type"))
        if "status" in updates:
            self.validate_memory_candidate_status(updates.get("status"))
        if "risk_level" in updates:
            self.validate_memory_candidate_risk_level(updates.get("risk_level"))
        if "payload" in updates and not isinstance(updates.get("payload"), dict):
            raise MemoryServiceError("Memory candidate payload must be an object.", 400)

        return await self.store._update_record(
            self.store.settings.supabase_memory_candidates_table,
            candidate_id,
            updates=updates,
            select=MEMORY_CANDIDATE_SELECT,
            empty_detail="At least one memory candidate field must be provided.",
        )

    def validate_memory_candidate_type(self, candidate_type: Optional[object]) -> None:
        if candidate_type is not None and candidate_type not in VALID_MEMORY_CANDIDATE_TYPES:
            raise MemoryServiceError("Invalid memory candidate type.", 400)

    def validate_memory_candidate_status(self, status: Optional[object]) -> None:
        if status is not None and status not in VALID_MEMORY_CANDIDATE_STATUSES:
            raise MemoryServiceError("Invalid memory candidate status.", 400)

    def validate_memory_candidate_risk_level(
        self,
        risk_level: Optional[object],
    ) -> None:
        if (
            risk_level is not None
            and risk_level not in VALID_MEMORY_CANDIDATE_RISK_LEVELS
        ):
            raise MemoryServiceError("Invalid memory candidate risk level.", 400)

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from app.models.memory_candidate import (
    MemoryCandidateApproveRequest,
    MemoryCandidateBulkDecisionRequest,
    MemoryCandidateCreateRequest,
    MemoryCandidateRejectRequest,
    MemoryCandidateUpdateRequest,
)
from app.services.memory_candidate_applier import MemoryCandidateApplier
from app.services.memory_candidate_preview import clean_optional, with_preview
from app.services.memory_correction_service import MemoryCorrectionService
from app.services.memory_discipline_service import MemoryDisciplineService
from app.services.memory_service import MemoryServiceError, SupabaseMemoryService
from app.services.memory_verification_service import MemoryVerificationService


class MemoryCandidateServiceError(Exception):
    def __init__(self, detail: str, status_code: int = 400) -> None:
        self.detail = detail
        self.status_code = status_code
        super().__init__(detail)


class MemoryCandidateService:
    def __init__(
        self,
        memory_service: SupabaseMemoryService,
        memory_discipline_service: MemoryDisciplineService | None = None,
        memory_correction_service: MemoryCorrectionService | None = None,
        memory_verification_service: MemoryVerificationService | None = None,
    ) -> None:
        self.memory_service = memory_service
        self.memory_discipline_service = (
            memory_discipline_service or MemoryDisciplineService(memory_service)
        )
        self.memory_correction_service = (
            memory_correction_service or MemoryCorrectionService(memory_service)
        )
        self.memory_verification_service = (
            memory_verification_service or MemoryVerificationService(memory_service)
        )
        self.candidate_applier = MemoryCandidateApplier(
            memory_service=memory_service,
            memory_correction_service=self.memory_correction_service,
            memory_discipline_service=self.memory_discipline_service,
        )

    async def create_candidate(
        self, request: MemoryCandidateCreateRequest
    ) -> dict[str, Any]:
        payload = request.model_dump(exclude_none=True)
        payload["payload"] = _clean_payload(payload.get("payload"))
        payload["reason"] = clean_optional(payload.get("reason"))
        try:
            row = await self.memory_service.create_memory_candidate(payload)
        except MemoryServiceError as error:
            raise MemoryCandidateServiceError(
                error.detail,
                error.status_code,
            ) from error
        return with_preview(row)

    async def list_candidates(
        self,
        *,
        candidate_type: str | None = None,
        status: str | None = None,
        risk_level: str | None = None,
        source_conversation_id: str | None = None,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        try:
            rows = await self.memory_service.list_memory_candidates(
                candidate_type=candidate_type,
                status=status,
                risk_level=risk_level,
                source_conversation_id=source_conversation_id,
                limit=limit,
            )
        except MemoryServiceError as error:
            raise MemoryCandidateServiceError(
                error.detail,
                error.status_code,
            ) from error
        return [with_preview(row) for row in rows]

    async def update_candidate(
        self,
        candidate_id: str,
        request: MemoryCandidateUpdateRequest,
    ) -> dict[str, Any]:
        updates = request.model_dump(exclude_none=True)
        if "payload" in updates:
            updates["payload"] = _clean_payload(updates["payload"])
        if "reason" in updates:
            updates["reason"] = clean_optional(updates["reason"])
        if not updates:
            raise MemoryCandidateServiceError(
                "At least one memory candidate field must be provided.",
                400,
            )

        row = await self._update_candidate(candidate_id, updates)
        return with_preview(row)

    async def approve_candidate(
        self,
        candidate_id: str,
        request: MemoryCandidateApproveRequest,
    ) -> dict[str, Any]:
        row = await self._get_pending_candidate(candidate_id)
        decision = {
            **(row.get("decision") or {}),
            **(request.decision or {}),
            "phase": "1b",
            "durable_apply_enabled": True,
        }
        approved_at = _now_iso()
        try:
            apply_result = await self.candidate_applier.apply_candidate(row)
        except Exception as error:
            failed = await self._update_candidate(
                candidate_id,
                {
                    "status": "failed",
                    "approved_by": clean_optional(request.approved_by) or "user",
                    "approved_at": approved_at,
                    "reason": clean_optional(request.reason) or row.get("reason"),
                    "decision": {
                        **decision,
                        "error": str(error),
                    },
                    "verification": {
                        "passed": False,
                        "message": "Candidate approval failed before durable write completed.",
                    },
                },
            )
            return with_preview(failed)

        if not apply_result.get("applied"):
            failed = await self._update_candidate(
                candidate_id,
                {
                    "status": "failed",
                    "approved_by": clean_optional(request.approved_by) or "user",
                    "approved_at": approved_at,
                    "reason": clean_optional(request.reason) or row.get("reason"),
                    "decision": {
                        **decision,
                        "apply_result": apply_result,
                    },
                    "verification": {
                        "passed": False,
                        "message": apply_result.get("reason")
                        or "Candidate could not be applied.",
                    },
                },
            )
            return with_preview(failed)

        verification = await self._verification_for_applied(
            candidate=row,
            apply_result=apply_result,
        )
        record = apply_result.get("record") or {}
        updated = await self._update_candidate(
            candidate_id,
            {
                "status": "applied" if verification.get("passed") else "failed",
                "approved_by": clean_optional(request.approved_by) or "user",
                "approved_at": approved_at,
                "applied_at": _now_iso() if verification.get("passed") else None,
                "reason": clean_optional(request.reason) or row.get("reason"),
                "decision": {
                    **decision,
                    "apply_result": {
                        "action": apply_result.get("action"),
                        "applied": True,
                    },
                },
                "applied_record_table": apply_result.get("table"),
                "applied_record_id": record.get("id"),
                "verification": verification,
            },
        )
        return with_preview(updated)

    async def reject_candidate(
        self,
        candidate_id: str,
        request: MemoryCandidateRejectRequest,
    ) -> dict[str, Any]:
        await self._get_pending_candidate(candidate_id)
        decision = {
            **(request.decision or {}),
            "phase": "1a",
            "rejected": True,
        }
        updates = {
            "status": "rejected",
            "rejected_at": _now_iso(),
            "reason": clean_optional(request.reason),
            "decision": decision,
        }
        updated = await self._update_candidate(candidate_id, updates)
        return with_preview(updated)

    async def bulk_approve_candidates(
        self,
        request: MemoryCandidateBulkDecisionRequest,
    ) -> dict[str, list[dict[str, Any]]]:
        candidates = await self._bulk_pending_candidates(request)
        approved: list[dict[str, Any]] = []
        skipped: list[dict[str, Any]] = []
        for candidate in candidates:
            if candidate.get("risk_level") == "high" and not request.include_high_risk:
                skipped.append(with_preview(candidate))
                continue
            approved.append(
                await self.approve_candidate(
                    candidate["id"],
                    MemoryCandidateApproveRequest(
                        approved_by=request.decided_by,
                        reason=request.reason,
                        decision={"bulk": True},
                    ),
                )
            )
        return {"approved": approved, "rejected": [], "skipped": skipped}

    async def bulk_reject_candidates(
        self,
        request: MemoryCandidateBulkDecisionRequest,
    ) -> dict[str, list[dict[str, Any]]]:
        candidates = await self._bulk_pending_candidates(request)
        rejected = [
            await self.reject_candidate(
                candidate["id"],
                MemoryCandidateRejectRequest(
                    reason=request.reason,
                    decision={"bulk": True, "decided_by": request.decided_by},
                ),
            )
            for candidate in candidates
        ]
        return {"approved": [], "rejected": rejected, "skipped": []}

    async def _bulk_pending_candidates(
        self,
        request: MemoryCandidateBulkDecisionRequest,
    ) -> list[dict[str, Any]]:
        if request.candidate_ids:
            candidates = [
                await self._get_pending_candidate(candidate_id)
                for candidate_id in request.candidate_ids
            ]
            return candidates
        return await self.list_candidates(
            status="pending",
            source_conversation_id=request.source_conversation_id,
            limit=100,
        )

    async def _get_pending_candidate(self, candidate_id: str) -> dict[str, Any]:
        try:
            row = await self.memory_service.get_memory_candidate(candidate_id)
        except MemoryServiceError as error:
            raise MemoryCandidateServiceError(
                error.detail,
                error.status_code,
            ) from error
        if row is None:
            raise MemoryCandidateServiceError("Pending memory candidate not found.", 404)
        if row.get("status") != "pending":
            raise MemoryCandidateServiceError("Pending memory candidate not found.", 404)
        return with_preview(row)

    async def _update_candidate(
        self, candidate_id: str, updates: dict[str, Any]
    ) -> dict[str, Any]:
        try:
            row = await self.memory_service.update_memory_candidate(
                candidate_id,
                **updates,
            )
        except MemoryServiceError as error:
            raise MemoryCandidateServiceError(
                error.detail,
                error.status_code,
            ) from error
        if row is None:
            raise MemoryCandidateServiceError("Memory candidate not found.", 404)
        return row

    async def _verification_for_applied(
        self,
        *,
        candidate: dict[str, Any],
        apply_result: dict[str, Any],
    ) -> dict[str, Any]:
        if candidate.get("candidate_type") == "correction":
            report = apply_result.get("correction_report") or {}
            verification = await self.memory_verification_service.verify_correction(
                stale_terms=apply_result.get("stale_terms") or [],
                applied_record={
                    "table": apply_result.get("table"),
                    "id": (apply_result.get("record") or {}).get("id"),
                },
            )
            verification["correction_report"] = report
            return verification

        record = apply_result.get("record") or {}
        table = apply_result.get("table")
        return await self.memory_verification_service.verify_applied_record(
            table=table,
            record_id=record.get("id"),
        )


def _clean_payload(payload: object) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise MemoryCandidateServiceError(
            "Memory candidate payload must be an object.",
            400,
        )
    return payload


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

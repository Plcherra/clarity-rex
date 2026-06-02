from typing import Optional

from app.models.memory_candidate import (
    MemoryCandidateApproveRequest,
    MemoryCandidateBulkDecisionRequest,
    MemoryCandidateRejectRequest,
    MemoryCandidateUpdateRequest,
)
from app.services.memory_candidate_decision_formatter import (
    MemoryCandidateDecisionFormatter,
)
from app.services.memory_candidate_review_intent import (
    EDIT_PENDING_MEMORY_PATTERN,
    MemoryCandidateReviewIntentClassifier,
    has_review_session_reference,
    normalized_confirmation_text,
)
from app.services.memory_candidate_review_session_service import (
    MemoryCandidateReviewSessionService,
)
from app.services.memory_candidate_service import MemoryCandidateService


class MemoryCandidateDecisionService:
    """Handles chat approvals/rejections/edits for pending memory candidates."""

    def __init__(
        self,
        memory_candidate_service: Optional[MemoryCandidateService],
        formatter: Optional[MemoryCandidateDecisionFormatter] = None,
        intent_classifier: Optional[MemoryCandidateReviewIntentClassifier] = None,
        review_session_service: Optional[
            MemoryCandidateReviewSessionService
        ] = None,
    ) -> None:
        self.memory_candidate_service = memory_candidate_service
        self.formatter = formatter or MemoryCandidateDecisionFormatter()
        self.intent_classifier = (
            intent_classifier or MemoryCandidateReviewIntentClassifier()
        )
        self.review_session_service = review_session_service or (
            MemoryCandidateReviewSessionService(memory_candidate_service.memory_service)
            if memory_candidate_service is not None
            and hasattr(memory_candidate_service, "memory_service")
            else None
        )

    async def handle_decision(
        self,
        message: str,
        *,
        conversation_id: str,
    ) -> Optional[dict]:
        if self.memory_candidate_service is None:
            return None

        intent = self.intent_classifier.classify(message)
        if intent is None:
            return None

        pending = await self.memory_candidate_service.list_candidates(
            status="pending",
            source_conversation_id=conversation_id,
            limit=20,
        )
        if not pending:
            if intent.kind in {"approve_all", "reject_all", "review", "edit"}:
                return self.formatter.no_pending_candidates_response()
            return None

        selected_candidate = self._candidate_from_confirmation_text(message, pending)

        if intent.kind == "edit":
            return await self._edit_pending_memory_candidate(message, pending)

        if intent.kind == "review":
            return await self._pending_candidates_response(
                pending,
                conversation_id=conversation_id,
            )

        if intent.kind == "approve_with_correction":
            return await self._update_pending_candidate_from_mixed_correction(
                pending,
                selected_candidate=selected_candidate,
                correction_text=intent.correction_text or message,
            )

        if intent.kind == "approve_all":
            session = await self._review_session_for_group_reference(
                message,
                conversation_id=conversation_id,
            )
            candidate_ids = self._session_candidate_ids(session)
            result = await self.memory_candidate_service.bulk_approve_candidates(
                MemoryCandidateBulkDecisionRequest(
                    source_conversation_id=conversation_id,
                    candidate_ids=candidate_ids,
                    decided_by="user",
                    reason="Approved from chat confirmation.",
                    include_high_risk=False,
                )
            )
            await self._complete_review_session(session)
            return self.formatter.candidate_decision_response(result)

        if intent.kind == "reject_all":
            session = await self._review_session_for_group_reference(
                message,
                conversation_id=conversation_id,
            )
            candidate_ids = self._session_candidate_ids(session)
            result = await self.memory_candidate_service.bulk_reject_candidates(
                MemoryCandidateBulkDecisionRequest(
                    source_conversation_id=conversation_id,
                    candidate_ids=candidate_ids,
                    decided_by="user",
                    reason="Rejected all pending changes from chat.",
                )
            )
            await self._complete_review_session(session)
            return self.formatter.candidate_decision_response(result)

        if intent.kind == "reject":
            candidate = selected_candidate or pending[0]
            rejected = await self.memory_candidate_service.reject_candidate(
                candidate["id"],
                MemoryCandidateRejectRequest(reason="Rejected from chat."),
            )
            return self.formatter.candidate_decision_response(
                {"approved": [], "rejected": [rejected], "skipped": []}
            )

        if len(pending) > 1 and selected_candidate is None:
            return await self._pending_candidates_response(
                pending,
                conversation_id=conversation_id,
            )

        candidate = selected_candidate or pending[0]
        if candidate.get("risk_level") == "high" and self.intent_classifier.is_vague_approval(message):
            return await self._pending_candidates_response(
                [candidate],
                conversation_id=conversation_id,
                response=(
                    "This is a high-risk memory change. Please confirm explicitly "
                    'with "confirm", "apply", or "save that" before I change '
                    "durable memory."
                ),
            )

        approved = await self.memory_candidate_service.approve_candidate(
            candidate["id"],
            MemoryCandidateApproveRequest(
                approved_by="user",
                reason="Approved from chat confirmation.",
            ),
        )
        return self.formatter.candidate_decision_response(
            {"approved": [approved], "rejected": [], "skipped": []}
        )

    async def _pending_candidates_response(
        self,
        pending: list[dict],
        *,
        conversation_id: str,
        response: Optional[str] = None,
    ) -> dict:
        result = self.formatter.pending_candidates_response(
            pending,
            response=response,
        )
        if self.review_session_service is None:
            return result
        session = await self.review_session_service.create_session(
            conversation_id=conversation_id,
            candidates=pending,
        )
        return self.review_session_service.with_session_payload(result, session)

    async def _review_session_for_group_reference(
        self,
        message: str,
        *,
        conversation_id: str,
    ) -> Optional[dict]:
        if self.review_session_service is None:
            return None
        normalized = normalized_confirmation_text(message)
        if not has_review_session_reference(normalized):
            return None
        return await self.review_session_service.latest_active_session(
            conversation_id=conversation_id,
        )

    def _session_candidate_ids(self, session: Optional[dict]) -> list[str]:
        if self.review_session_service is None:
            return []
        return self.review_session_service.session_candidate_ids(session)

    async def _complete_review_session(self, session: Optional[dict]) -> None:
        if self.review_session_service is None or session is None:
            return
        await self.review_session_service.complete_session(session)

    def _candidate_from_confirmation_text(
        self,
        message: str,
        candidates: list[dict],
    ) -> Optional[dict]:
        normalized = normalized_confirmation_text(message)
        if not normalized:
            return None
        for candidate in candidates:
            candidate_id = str(candidate.get("id") or "")
            if not candidate_id:
                continue
            normalized_id = normalized_confirmation_text(candidate_id)
            compact_id = normalized_id.replace(" ", "")
            if normalized_id and normalized_id in normalized:
                return candidate
            if compact_id and compact_id in normalized.replace(" ", ""):
                return candidate
            if len(compact_id) >= 8 and compact_id[-8:] in normalized.replace(" ", ""):
                return candidate
        return None

    async def _update_pending_candidate_from_mixed_correction(
        self,
        pending: list[dict],
        *,
        selected_candidate: Optional[dict],
        correction_text: str,
    ) -> Optional[dict]:
        if self.memory_candidate_service is None:
            return None
        candidate = selected_candidate or self._single_correction_candidate(pending)
        if candidate is None:
            return self.formatter.pending_candidates_response(
                pending,
                response=(
                    "I caught the correction, but I need to know which pending "
                    "memory request to update. Say the candidate id or edit it "
                    "from the Memory tab."
                ),
            )

        payload = self._edited_candidate_payload(candidate, correction_text)
        updated = await self.memory_candidate_service.update_candidate(
            candidate["id"],
            MemoryCandidateUpdateRequest(
                payload=payload,
                reason="Edited by the user before approval.",
            ),
        )
        return self.formatter.updated_candidate_response(updated)

    def _single_correction_candidate(self, pending: list[dict]) -> Optional[dict]:
        correction_candidates = [
            candidate
            for candidate in pending
            if str(candidate.get("candidate_type") or "") == "correction"
        ]
        if len(correction_candidates) == 1:
            return correction_candidates[0]
        if len(pending) == 1:
            return pending[0]
        return None

    async def _edit_pending_memory_candidate(
        self,
        message: str,
        pending: list[dict],
    ) -> Optional[dict]:
        if self.memory_candidate_service is None:
            return None

        match = EDIT_PENDING_MEMORY_PATTERN.match(message.strip())
        if match is None:
            return None

        candidate_id = match.group(1).strip()
        proposal = " ".join(match.group(2).split())
        if not candidate_id or not proposal:
            return None

        normalized_candidate_id = normalized_confirmation_text(candidate_id)
        candidate = next(
            (
                item
                for item in pending
                if normalized_confirmation_text(str(item.get("id") or ""))
                == normalized_candidate_id
            ),
            None,
        )
        if candidate is None:
            return None

        payload = self._edited_candidate_payload(candidate, proposal)
        updated = await self.memory_candidate_service.update_candidate(
            candidate["id"],
            MemoryCandidateUpdateRequest(
                payload=payload,
                reason="Edited by the user before approval.",
            ),
        )
        return self.formatter.updated_candidate_response(updated)

    def _edited_candidate_payload(self, candidate: dict, proposal: str) -> dict:
        payload = dict(candidate.get("payload") or {})
        key = self._candidate_primary_text_key(candidate, payload)
        payload[key] = proposal
        return payload

    def _candidate_primary_text_key(self, candidate: dict, payload: dict) -> str:
        candidate_type = str(candidate.get("candidate_type") or "")
        keys = {
            "entity": ("display_name", "title", "content"),
            "personal_rule": ("rule_text", "title", "content"),
            "commitment": ("commitment_text", "title", "content"),
            "correction": ("text", "content"),
            "plan": ("title", "description", "content"),
            "plan_milestone": ("title", "description", "content"),
            "entity_event": ("title", "content", "description"),
        }.get(candidate_type, ("content", "title", "new_value"))
        for key in keys:
            value = payload.get(key)
            if isinstance(value, str) and value.strip():
                return key
        return keys[0]

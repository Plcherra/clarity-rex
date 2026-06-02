import re
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
from app.services.memory_candidate_service import MemoryCandidateService


APPROVE_ALL_PHRASES = {
    "approve all",
    "approve all pending",
    "apply all",
    "apply all pending",
    "confirm all",
    "save all",
    "save all pending",
}
REJECT_ALL_PHRASES = {
    "reject all",
    "reject all pending",
    "discard all",
    "discard all pending",
    "do not save any",
    "dont save any",
}
EDIT_PENDING_MEMORY_PATTERN = re.compile(
    r"^edit\s+pending\s+memory\s+([A-Za-z0-9_-]+)\s*:\s*(.+)$",
    re.IGNORECASE | re.DOTALL,
)
APPROVE_PHRASES = {
    "yes",
    "yep",
    "yeah",
    "ok",
    "okay",
    "sure",
    "confirm",
    "confirmed",
    "do it",
    "apply",
    "approve",
    "approve it",
    "save it",
    "save that",
    "looks good",
}
VAGUE_APPROVE_PHRASES = {
    "yes",
    "yep",
    "yeah",
    "ok",
    "okay",
    "sure",
}
REJECT_PHRASES = {
    "no",
    "nope",
    "reject",
    "discard",
    "dont save",
    "do not save",
    "cancel",
}

class MemoryCandidateDecisionService:
    """Handles chat approvals/rejections/edits for pending memory candidates."""

    def __init__(
        self,
        memory_candidate_service: Optional[MemoryCandidateService],
        formatter: Optional[MemoryCandidateDecisionFormatter] = None,
    ) -> None:
        self.memory_candidate_service = memory_candidate_service
        self.formatter = formatter or MemoryCandidateDecisionFormatter()

    async def handle_decision(
        self,
        message: str,
        *,
        conversation_id: str,
    ) -> Optional[dict]:
        if self.memory_candidate_service is None:
            return None

        intent = self._decision_intent(message)
        if intent is None:
            return None

        pending = await self.memory_candidate_service.list_candidates(
            status="pending",
            source_conversation_id=conversation_id,
            limit=20,
        )
        if not pending:
            return None

        selected_candidate = self._candidate_from_confirmation_text(message, pending)

        if intent == "edit":
            return await self._edit_pending_memory_candidate(message, pending)

        if intent == "approve_all":
            result = await self.memory_candidate_service.bulk_approve_candidates(
                MemoryCandidateBulkDecisionRequest(
                    source_conversation_id=conversation_id,
                    decided_by="user",
                    reason="Approved from chat confirmation.",
                    include_high_risk=False,
                )
            )
            return self.formatter.candidate_decision_response(result)

        if intent == "reject_all":
            result = await self.memory_candidate_service.bulk_reject_candidates(
                MemoryCandidateBulkDecisionRequest(
                    source_conversation_id=conversation_id,
                    decided_by="user",
                    reason="Rejected all pending changes from chat.",
                )
            )
            return self.formatter.candidate_decision_response(result)

        if intent == "reject":
            candidate = selected_candidate or pending[0]
            rejected = await self.memory_candidate_service.reject_candidate(
                candidate["id"],
                MemoryCandidateRejectRequest(reason="Rejected from chat."),
            )
            return self.formatter.candidate_decision_response(
                {"approved": [], "rejected": [rejected], "skipped": []}
            )

        if len(pending) > 1 and selected_candidate is None:
            return self.formatter.pending_candidates_response(pending)

        candidate = selected_candidate or pending[0]
        if candidate.get("risk_level") == "high" and self._is_vague_approval(message):
            return self.formatter.pending_candidates_response(
                [candidate],
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

    def _decision_intent(self, message: str) -> Optional[str]:
        normalized = self._normalized_confirmation_text(message)
        if not normalized:
            return None
        if normalized in APPROVE_ALL_PHRASES:
            return "approve_all"
        if normalized in REJECT_ALL_PHRASES:
            return "reject_all"
        if (
            "approve" in normalized or "apply" in normalized or "save" in normalized
        ) and ("all" in normalized or "pending" in normalized or "these" in normalized):
            return "approve_all"
        if ("reject" in normalized or "discard" in normalized) and (
            "all" in normalized or "pending" in normalized or "these" in normalized
        ):
            return "reject_all"
        if EDIT_PENDING_MEMORY_PATTERN.match(message.strip()):
            return "edit"
        if normalized in REJECT_PHRASES:
            return "reject"
        if normalized.startswith("do not save ") or normalized.startswith("dont save "):
            return "reject"
        if normalized in APPROVE_PHRASES:
            return "approve"
        if normalized.startswith(("confirm ", "confirmed ", "approve ", "apply ")):
            return "approve"
        if normalized.startswith("save ") and "all" not in normalized:
            return "approve"
        return None

    def _is_vague_approval(self, message: str) -> bool:
        return self._normalized_confirmation_text(message) in VAGUE_APPROVE_PHRASES

    def _candidate_from_confirmation_text(
        self,
        message: str,
        candidates: list[dict],
    ) -> Optional[dict]:
        normalized = self._normalized_confirmation_text(message)
        if not normalized:
            return None
        for candidate in candidates:
            candidate_id = str(candidate.get("id") or "")
            if not candidate_id:
                continue
            normalized_id = self._normalized_confirmation_text(candidate_id)
            compact_id = normalized_id.replace(" ", "")
            if normalized_id and normalized_id in normalized:
                return candidate
            if compact_id and compact_id in normalized.replace(" ", ""):
                return candidate
            if len(compact_id) >= 8 and compact_id[-8:] in normalized.replace(" ", ""):
                return candidate
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

        normalized_candidate_id = self._normalized_confirmation_text(candidate_id)
        candidate = next(
            (
                item
                for item in pending
                if self._normalized_confirmation_text(str(item.get("id") or ""))
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

    def _normalized_confirmation_text(self, message: str) -> str:
        normalized = message.lower().replace("'", "")
        normalized = "".join(
            character if character.isalnum() or character.isspace() else " "
            for character in normalized
        )
        return " ".join(normalized.split())

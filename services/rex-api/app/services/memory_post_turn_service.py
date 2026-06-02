import asyncio
import json
from typing import Optional

from app.models.memory_candidate import MemoryCandidateCreateRequest
from app.services.memory_candidate_service import MemoryCandidateService
from app.services.memory_correction_service import MemoryCorrectionService
from app.services.memory_extraction_service import MemoryExtractionService
from app.services.memory_path_policy import pending_review_metadata


class MemoryPostTurnService:
    def __init__(
        self,
        *,
        memory_extraction_service: Optional[MemoryExtractionService] = None,
        memory_correction_service: Optional[MemoryCorrectionService] = None,
        memory_candidate_service: Optional[MemoryCandidateService] = None,
    ) -> None:
        self.memory_extraction_service = memory_extraction_service
        self.memory_correction_service = memory_correction_service
        self.memory_candidate_service = memory_candidate_service
        self._background_tasks: set[asyncio.Task[None]] = set()

    async def apply_memory_correction(
        self,
        message: str,
        *,
        conversation_id: str,
        user_message_id: str,
        brain_metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        if self.memory_correction_service is None:
            return None
        try:
            intent = self.memory_correction_service.detect_correction_intent(message)
            if intent.confidence < 0.5:
                return None
        except Exception:
            return None
        if self.memory_candidate_service is None:
            return None
        reason = (
            "User correction detected. It must be confirmed before anything "
            "durable is changed."
        )
        candidate_metadata = self.memory_candidate_metadata(
            pending_review_metadata(
                {
                    "correction_intent": True,
                    "phase": "2_pending_verified_correction",
                },
                candidate_type="correction",
                risk_level="high",
                rationale=reason,
            ),
            brain_metadata=brain_metadata,
        )
        try:
            candidate = await self.memory_candidate_service.create_candidate(
                MemoryCandidateCreateRequest(
                    candidate_type="correction",
                    payload={
                        "text": message,
                        "intent": {
                            "intent_type": intent.intent_type.value,
                            "old_value": intent.old_value,
                            "new_value": intent.new_value,
                            "target_hint": intent.target_hint,
                            "confidence": intent.confidence,
                        },
                        "metadata": candidate_metadata,
                    },
                    risk_level="high",
                    reason=reason,
                    source_conversation_id=conversation_id,
                    source_message_id=user_message_id or None,
                )
            )
        except Exception:
            return None
        return {
            "applied": False,
            "requires_confirmation": True,
            "candidate_id": candidate.get("id"),
            "candidate_type": candidate.get("candidate_type"),
            "risk_level": candidate.get("risk_level"),
            "preview": candidate.get("preview"),
            "old_value": intent.old_value,
            "new_value": intent.new_value,
            "target_hint": intent.target_hint,
            "message": "Correction captured as a pending memory candidate.",
            "memory_path": "pending_review",
            "review_required": True,
            "review_reason": candidate_metadata.get("review_reason"),
        }

    def memory_candidate_metadata(
        self,
        metadata: dict,
        *,
        brain_metadata: Optional[dict] = None,
    ) -> dict:
        merged = dict(metadata)
        if brain_metadata:
            merged["rex_brain"] = brain_metadata
        return merged

    def memory_correction_prompt(self, memory_correction: dict) -> dict:
        payload = json.dumps(memory_correction, sort_keys=True)
        return {
            "role": "system",
            "content": (
                "Memory correction status for this turn: "
                f"{payload}\n"
                "If applied, briefly tell the user exactly what was updated or archived. "
                "If confirmation is required, ask for confirmation before claiming it was changed."
            ),
        }

    def correction_blocks_extraction(self, memory_correction: Optional[dict]) -> bool:
        if not memory_correction:
            return False
        return bool(
            memory_correction.get("applied")
            or memory_correction.get("requires_confirmation")
        )

    def memory_change_summary(
        self,
        extraction_results: list[dict],
        *,
        memory_correction: Optional[dict] = None,
        skipped_reason: Optional[str] = None,
    ) -> Optional[dict]:
        summary = {
            "created": 0,
            "updated": 0,
            "archived": 0,
            "merged": 0,
            "skipped": 0,
            "confirmation_required": 0,
            "records": [],
        }

        if memory_correction:
            if memory_correction.get("requires_confirmation"):
                summary["confirmation_required"] += 1
            if memory_correction.get("applied"):
                summary["updated"] += len(memory_correction.get("updated") or [])
                summary["archived"] += len(memory_correction.get("archived") or [])
                summary["created"] += len(memory_correction.get("created") or [])
                summary["merged"] += len(memory_correction.get("merged") or [])
            summary["records"].append(
                {
                    "kind": "memory_correction",
                    "applied": bool(memory_correction.get("applied")),
                    "requires_confirmation": bool(
                        memory_correction.get("requires_confirmation")
                    ),
                    "memory_path": memory_correction.get("memory_path"),
                    "review_required": memory_correction.get("review_required"),
                    "review_reason": memory_correction.get("review_reason"),
                }
            )

        if skipped_reason:
            summary["skipped"] += 1
            summary["records"].append(
                {
                    "kind": "memory_extraction",
                    "action": "skipped",
                    "reason": skipped_reason,
                }
            )

        for result in extraction_results:
            action = str(result.get("extraction_action") or "create")
            if action.startswith("create"):
                summary["created"] += 1
            elif action.startswith("update") or action == "updated_correction":
                summary["updated"] += 1
            elif action.startswith("archive"):
                summary["archived"] += 1
            elif action.startswith("merge"):
                summary["merged"] += 1
            elif action in {"ask_confirmation", "confirmation_required"}:
                summary["confirmation_required"] += 1
            elif action in {"candidate_created", "candidate_reused"}:
                summary["confirmation_required"] += 1
            elif action.startswith("skip") or action.startswith("ignore"):
                summary["skipped"] += 1

            summary["records"].append(
                {
                    "kind": result.get("extraction_kind"),
                    "type": result.get("structured_type") or result.get("memory_type"),
                    "action": action,
                    "id": result.get("id"),
                    "title": result.get("title")
                    or result.get("display_name")
                    or result.get("content"),
                    "reason": result.get("reason"),
                    "memory_path": result.get("memory_path"),
                    "review_required": result.get("review_required"),
                    "review_reason": result.get("review_reason"),
                }
            )

        if not any(
            summary[key]
            for key in (
                "created",
                "updated",
                "archived",
                "merged",
                "skipped",
                "confirmation_required",
            )
        ):
            return None
        return summary

    async def extract_memory_after_success(
        self,
        conversation_id: str,
        user_message: dict,
        assistant_message: dict,
        brain_metadata: Optional[dict] = None,
    ) -> list[dict]:
        if self.memory_extraction_service is None:
            return []

        try:
            return await self.memory_extraction_service.extract_and_save(
                conversation_id=conversation_id,
                user_message=user_message,
                assistant_message=assistant_message,
                brain_metadata=brain_metadata,
            )
        except Exception:
            return [
                {
                    "extraction_kind": "memory_extraction",
                    "extraction_action": "skip_failed",
                    "reason": "Memory extraction failed after the response.",
                }
            ]

    def schedule_memory_extraction(
        self,
        conversation_id: str,
        user_message: dict,
        assistant_message: dict,
        brain_metadata: Optional[dict] = None,
    ) -> None:
        if self.memory_extraction_service is None:
            return

        task = asyncio.create_task(
            self.extract_memory_after_success(
                conversation_id,
                user_message,
                assistant_message,
                brain_metadata=brain_metadata,
            )
        )
        self._background_tasks.add(task)
        task.add_done_callback(self._background_tasks.discard)

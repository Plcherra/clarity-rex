from typing import Optional


LOW_RISK_AUTO_APPLY_ENABLED = False


class MemoryCandidateDecisionFormatter:
    """Builds user-facing pending memory candidate decision payloads."""

    def updated_candidate_response(self, updated: dict) -> dict:
        card = self.candidate_card(updated)
        return {
            "response": "Updated 1 pending memory request. Review it before saving.",
            "memory_changes": {
                "created": 0,
                "updated": 0,
                "archived": 0,
                "merged": 0,
                "skipped": 0,
                "confirmation_required": 1,
                "low_risk_auto_apply_enabled": LOW_RISK_AUTO_APPLY_ENABLED,
                "pending_candidates": [card],
                "records": [
                    {
                        "kind": "memory_candidate",
                        "action": "updated_pending",
                        "id": updated.get("id"),
                        "title": updated.get("preview"),
                        "candidate": card,
                    }
                ],
            },
        }

    def pending_candidates_response(
        self,
        pending: list[dict],
        *,
        response: Optional[str] = None,
    ) -> dict:
        if response is None:
            response = (
                f"I found {len(pending)} memory update(s) that need review. "
                'Review the memory card(s), then say "approve all pending" '
                'for eligible low/medium-risk changes, "confirm" for a single '
                'high-risk change, or "do not save" to reject the latest one.'
            )
        cards = [self.candidate_card(candidate) for candidate in pending]
        return {
            "response": response,
            "memory_changes": {
                "created": 0,
                "updated": 0,
                "archived": 0,
                "merged": 0,
                "skipped": 0,
                "confirmation_required": len(pending),
                "low_risk_auto_apply_enabled": LOW_RISK_AUTO_APPLY_ENABLED,
                "pending_candidates": cards,
                "records": [
                    {
                        "kind": "memory_candidate",
                        "action": "pending",
                        "id": candidate.get("id"),
                        "title": candidate.get("preview"),
                        "candidate": card,
                    }
                    for candidate, card in zip(pending, cards)
                ],
            },
        }

    def candidate_decision_response(self, result: dict) -> dict:
        approved = result.get("approved") or []
        rejected = result.get("rejected") or []
        skipped = result.get("skipped") or []
        failed = [
            candidate
            for candidate in approved
            if candidate.get("status") == "failed"
            or not (candidate.get("verification") or {}).get("passed", False)
        ]
        applied = [
            candidate
            for candidate in approved
            if candidate.get("status") == "applied"
            and (candidate.get("verification") or {}).get("passed", False)
        ]

        parts: list[str] = []
        if applied:
            parts.append(f"Applied {len(applied)} pending memory change(s).")
        if rejected:
            parts.append(f"Rejected {len(rejected)} pending memory change(s).")
        if skipped:
            parts.append(
                f"Skipped {len(skipped)} high-risk pending change(s); those need "
                "explicit individual confirmation."
            )
        if failed:
            parts.append(
                "Some pending changes failed verification, so I did not mark them done."
            )
            remaining = self.remaining_conflict_text(failed)
            if remaining:
                parts.append(f"Still wrong: {remaining}")
        response = " ".join(parts) or "No pending memory changes were applied."

        applied_cards = [self.candidate_card(candidate) for candidate in applied]
        rejected_cards = [self.candidate_card(candidate) for candidate in rejected]
        skipped_cards = [self.candidate_card(candidate) for candidate in skipped]
        failed_cards = [self.candidate_card(candidate) for candidate in failed]

        return {
            "response": response,
            "memory_changes": {
                "created": len(applied),
                "updated": 0,
                "archived": 0,
                "merged": 0,
                "skipped": len(skipped) + len(failed),
                "confirmation_required": len(skipped),
                "low_risk_auto_apply_enabled": LOW_RISK_AUTO_APPLY_ENABLED,
                "applied_candidates": applied_cards,
                "rejected_candidates": rejected_cards,
                "skipped_candidates": skipped_cards,
                "failed_candidates": failed_cards,
                "pending_candidates": skipped_cards + failed_cards,
                "records": [
                    *[
                        {
                            "kind": "memory_candidate",
                            "action": candidate.get("status"),
                            "id": candidate.get("id"),
                            "title": candidate.get("preview"),
                            "candidate": card,
                        }
                        for candidate, card in zip(applied, applied_cards)
                    ],
                    *[
                        {
                            "kind": "memory_candidate",
                            "action": "rejected",
                            "id": candidate.get("id"),
                            "title": candidate.get("preview"),
                            "candidate": card,
                        }
                        for candidate, card in zip(rejected, rejected_cards)
                    ],
                    *[
                        {
                            "kind": "memory_candidate",
                            "action": "skipped_high_risk",
                            "id": candidate.get("id"),
                            "title": candidate.get("preview"),
                            "candidate": card,
                        }
                        for candidate, card in zip(skipped, skipped_cards)
                    ],
                    *[
                        {
                            "kind": "memory_candidate",
                            "action": "verification_failed",
                            "id": candidate.get("id"),
                            "title": candidate.get("preview"),
                            "candidate": card,
                        }
                        for candidate, card in zip(failed, failed_cards)
                    ],
                ],
            },
        }

    def candidate_card(self, candidate: dict) -> dict:
        verification = candidate.get("verification") or {}
        applied_record_table = candidate.get("applied_record_table")
        applied_record_id = candidate.get("applied_record_id")
        payload = candidate.get("payload") or {}
        return {
            "id": candidate.get("id"),
            "candidate_type": candidate.get("candidate_type"),
            "status": candidate.get("status"),
            "risk_level": candidate.get("risk_level"),
            "preview": candidate.get("preview"),
            "reason": candidate.get("reason"),
            "review_reason": self.review_reason(candidate),
            "memory_path": self.memory_path(candidate),
            "review_required": True,
            "expected_action": self.candidate_expected_action(candidate),
            "requires_explicit_confirmation": candidate.get("risk_level") == "high",
            "source_conversation_id": candidate.get("source_conversation_id"),
            "source_message_id": candidate.get("source_message_id"),
            "payload_preview": self.payload_preview(payload),
            "applied_record": (
                {
                    "table": applied_record_table,
                    "id": applied_record_id,
                }
                if applied_record_table or applied_record_id
                else None
            ),
            "verification": self.verification_summary(verification),
        }

    def candidate_expected_action(self, candidate: dict) -> str:
        candidate_type = str(candidate.get("candidate_type") or "")
        return {
            "long_term_memory": "Create long-term memory after confirmation",
            "entity": "Create or update canonical entity after confirmation",
            "entity_event": "Create historical entity event after confirmation",
            "personal_rule": "Create or update personal rule after confirmation",
            "plan": "Create or update top-level plan after confirmation",
            "plan_milestone": "Create or update achievement milestone after confirmation",
            "commitment": "Create or update task/commitment after confirmation",
            "correction": "Review correction before changing saved memory",
            "archive": "Archive stale record after confirmation",
            "merge": "Merge duplicate records after confirmation",
        }.get(candidate_type, "Apply pending memory change after confirmation")

    def review_reason(self, candidate: dict) -> Optional[str]:
        payload = candidate.get("payload") or {}
        metadata = payload.get("metadata") if isinstance(payload, dict) else {}
        if isinstance(metadata, dict):
            review_reason = metadata.get("review_reason")
            if review_reason:
                return str(review_reason)
        reason = candidate.get("reason")
        return str(reason) if reason else None

    def memory_path(self, candidate: dict) -> Optional[str]:
        payload = candidate.get("payload") or {}
        metadata = payload.get("metadata") if isinstance(payload, dict) else {}
        if not isinstance(metadata, dict):
            return None
        memory_path = metadata.get("memory_path")
        return str(memory_path) if memory_path else None

    def payload_preview(self, payload: dict) -> dict:
        preview: dict[str, object] = {}
        for key in (
            "title",
            "display_name",
            "content",
            "description",
            "rule_text",
            "commitment_text",
            "text",
        ):
            value = payload.get(key)
            if value is None:
                continue
            text = " ".join(str(value).split())
            if text:
                preview[key] = text[:240]
        intent = payload.get("intent")
        if isinstance(intent, dict):
            preview["intent"] = {
                key: intent.get(key)
                for key in ("intent_type", "old_value", "new_value", "target_hint")
                if intent.get(key) is not None
            }
        return preview

    def verification_summary(self, verification: dict) -> Optional[dict]:
        if not verification:
            return None
        remaining = verification.get("remaining_conflicts") or []
        return {
            "passed": bool(verification.get("passed")),
            "message": verification.get("message"),
            "remaining_conflict_count": len(remaining),
            "remaining_conflicts": remaining[:5],
            "applied_record": verification.get("applied_record"),
        }

    def remaining_conflict_text(self, candidates: list[dict]) -> str:
        conflicts: list[str] = []
        for candidate in candidates:
            verification = candidate.get("verification") or {}
            for conflict in verification.get("remaining_conflicts") or []:
                table = conflict.get("table") or "record"
                title = conflict.get("title") or conflict.get("id") or "unknown"
                terms = ", ".join(conflict.get("matched_terms") or [])
                conflicts.append(f"{table} {title} still contains {terms}".strip())
        return "; ".join(conflicts[:5])

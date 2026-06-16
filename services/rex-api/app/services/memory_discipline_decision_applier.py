from __future__ import annotations

from typing import Any

from app.models.memory_discipline import (
    MemoryRecordKind,
    MemoryDisciplineAction,
    MemoryDisciplineDecision,
)
from app.services.entity_normalization_service import EntityNormalizationService
from app.services.memory_discipline_similarity import meaningful_tokens, normalize_text


class MemoryDisciplineDecisionApplier:
    """Applies approved discipline decisions through the memory repository."""

    def __init__(
        self,
        memory_service,
        *,
        scan_limit: int,
        entity_normalization_service: EntityNormalizationService | None = None,
    ) -> None:
        self.memory_service = memory_service
        self.scan_limit = scan_limit
        self.entity_normalization_service = (
            entity_normalization_service or EntityNormalizationService()
        )

    async def apply_decision(self, decision: MemoryDisciplineDecision) -> dict:
        normalized_payload = await self._normalize_decision_payload(decision)
        payload = {
            **normalized_payload,
            "metadata": {
                **self._target_metadata(decision),
                **(normalized_payload.get("metadata") or {}),
                **decision.metadata,
            },
        }
        action = decision.action
        target_id = decision.target_id

        if action == MemoryDisciplineAction.IGNORE_NOISY_CANDIDATE:
            return {"action": action.value, "applied": False, "reason": decision.reason}
        if action == MemoryDisciplineAction.ASK_CONFIRMATION:
            return {
                "action": action.value,
                "applied": False,
                "requires_confirmation": True,
                "reason": decision.reason,
                "related_records": [
                    record.model_dump() for record in decision.related_records
                ],
            }

        create_method = create_method_for_action(action)
        if create_method:
            created = await getattr(self.memory_service, create_method)(payload)
            if not isinstance(created, dict) or not created.get("id"):
                return {
                    "action": action.value,
                    "applied": False,
                    "reason": "Durable create was not confirmed.",
                }
            return {"action": action.value, "applied": True, "record": created}

        update_method = update_method_for_action(action)
        if update_method and target_id:
            payload = self._merge_update_payload(decision, payload)
            updated = await getattr(self.memory_service, update_method)(
                target_id,
                **payload,
            )
            if not isinstance(updated, dict) or not updated.get("id"):
                return {
                    "action": action.value,
                    "applied": False,
                    "reason": "Durable update was not confirmed.",
                }
            return {"action": action.value, "applied": True, "record": updated}

        archive_method = archive_method_for_action(action)
        if archive_method and target_id:
            archived = await getattr(self.memory_service, archive_method)(target_id)
            return {"action": action.value, "applied": bool(archived)}

        raise ValueError(f"Unsupported memory discipline action: {action.value}")

    async def _normalize_decision_payload(
        self,
        decision: MemoryDisciplineDecision,
    ) -> dict[str, Any]:
        payload = dict(decision.payload)
        entities = await self._safe_list(
            "list_entities",
            active=True,
            limit=self.scan_limit,
        )
        if not entities:
            return payload
        if decision.record_kind == MemoryRecordKind.ENTITY:
            return self.entity_normalization_service.normalize_candidate_entity(
                payload,
                entities,
            ).payload

        text_fields_by_kind: dict[MemoryRecordKind, tuple[str, ...]] = {
            MemoryRecordKind.PERSONAL_RULE: (
                "title",
                "rule_text",
                "trigger_keywords",
            ),
            MemoryRecordKind.PLAN: ("title", "description", "desired_outcome"),
            MemoryRecordKind.PLAN_MILESTONE: ("title", "description"),
            MemoryRecordKind.COMMITMENT: ("title", "commitment_text"),
            MemoryRecordKind.ENTITY_EVENT: ("title", "content"),
        }
        text_fields = text_fields_by_kind.get(decision.record_kind)
        if text_fields is None:
            return payload
        link_field = None
        if decision.record_kind == MemoryRecordKind.PLAN:
            link_field = "primary_entity_id"
        elif decision.record_kind == MemoryRecordKind.COMMITMENT:
            link_field = "entity_id"
        return self.entity_normalization_service.normalize_payload_references(
            payload,
            entities,
            text_fields=text_fields,
            link_field=link_field,
        ).payload

    async def _safe_list(self, method_name: str, **kwargs: Any) -> list[dict]:
        method = getattr(self.memory_service, method_name, None)
        if method is None:
            return []
        try:
            return await method(**kwargs)
        except TypeError:
            return await method(limit=kwargs.get("limit", self.scan_limit))
        except Exception:
            return []

    def _target_metadata(self, decision: MemoryDisciplineDecision) -> dict[str, Any]:
        target = self._target_record(decision)
        return dict(target.get("metadata") or {}) if target else {}

    def _target_record(self, decision: MemoryDisciplineDecision) -> dict[str, Any]:
        if not decision.target_id:
            return {}
        for related in decision.related_records:
            if related.id == decision.target_id:
                return dict(related.record)
        return {}

    def _merge_update_payload(
        self,
        decision: MemoryDisciplineDecision,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        if decision.action != MemoryDisciplineAction.UPDATE_ENTITY:
            return payload

        target = self._target_record(decision)
        if not target:
            return payload

        merged = dict(payload)
        candidate_display = str(payload.get("display_name") or "").strip()
        target_display = str(target.get("display_name") or "").strip()
        candidate_normalized = normalize_text(
            payload.get("normalized_name") or candidate_display
        )
        target_normalized = normalize_text(
            target.get("normalized_name") or target_display
        )

        if target_display and target_normalized:
            candidate_tokens = meaningful_tokens(candidate_normalized)
            target_tokens = meaningful_tokens(target_normalized)
            alias_values = {
                normalize_text(alias)
                for alias in target.get("aliases") or []
                if normalize_text(alias)
            }
            if (
                target_tokens
                and target_tokens <= candidate_tokens
                or candidate_normalized in alias_values
            ):
                merged["display_name"] = target_display
                merged["normalized_name"] = target.get("normalized_name") or target_normalized

        aliases = []
        for value in [
            *(target.get("aliases") or []),
            *(payload.get("aliases") or []),
        ]:
            if value and str(value) not in aliases:
                aliases.append(str(value))
        if (
            candidate_display
            and target_display
            and candidate_display.casefold() != target_display.casefold()
            and candidate_display not in aliases
        ):
            aliases.append(candidate_display)
        merged["aliases"] = aliases
        return merged


def create_method_for_action(action: MemoryDisciplineAction) -> str | None:
    return {
        MemoryDisciplineAction.CREATE_ENTITY: "create_entity",
        MemoryDisciplineAction.CREATE_ENTITY_EVENT: "create_entity_event",
        MemoryDisciplineAction.CREATE_PLAN: "create_plan",
        MemoryDisciplineAction.CREATE_MILESTONE: "create_plan_milestone",
        MemoryDisciplineAction.CREATE_COMMITMENT: "create_commitment",
        MemoryDisciplineAction.CREATE_RULE: "create_personal_rule",
    }.get(action)


def update_method_for_action(action: MemoryDisciplineAction) -> str | None:
    return {
        MemoryDisciplineAction.UPDATE_ENTITY: "update_entity",
        MemoryDisciplineAction.UPDATE_PLAN: "update_plan",
        MemoryDisciplineAction.UPDATE_MILESTONE: "update_plan_milestone",
        MemoryDisciplineAction.UPDATE_COMMITMENT: "update_commitment",
        MemoryDisciplineAction.UPDATE_RULE: "update_personal_rule",
    }.get(action)


def archive_method_for_action(action: MemoryDisciplineAction) -> str | None:
    return {
        MemoryDisciplineAction.ARCHIVE_ENTITY: "deactivate_entity",
        MemoryDisciplineAction.ARCHIVE_PLAN: "deactivate_plan",
        MemoryDisciplineAction.ARCHIVE_RULE: "deactivate_personal_rule",
    }.get(action)

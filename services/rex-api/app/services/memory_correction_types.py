from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Optional, Protocol


CORRECTION_VERSION = 1
HIGH_IMPACT_RECORD_THRESHOLD = 5


class CorrectionIntentType(str, Enum):
    REPLACE_VALUE = "replace_value"
    REMOVE_OBSOLETE = "remove_obsolete"
    MERGE_ITEMS = "merge_items"
    MOVE_UNDER_PARENT = "move_under_parent"
    DOWNGRADE_PLAN_TO_TASK = "downgrade_plan_to_task"
    UNKNOWN = "unknown"


@dataclass(frozen=True)
class CorrectionIntent:
    intent_type: CorrectionIntentType
    old_value: Optional[str] = None
    new_value: Optional[str] = None
    target_hint: Optional[str] = None
    confidence: float = 0.75
    requires_confirmation: bool = False
    delete_scope_tables: tuple[str, ...] = ()
    is_vague_delete_reference: bool = False


@dataclass
class CorrectionAffectedRecord:
    table: str
    id: str
    action: str
    title: Optional[str] = None
    previous: dict[str, Any] = field(default_factory=dict)
    updated: Optional[dict[str, Any]] = None


@dataclass
class CorrectionReport:
    intent: CorrectionIntent
    applied: bool = False
    requires_confirmation: bool = False
    affected_records: list[CorrectionAffectedRecord] = field(default_factory=list)
    corrections: list[dict[str, Any]] = field(default_factory=list)
    errors: list[dict[str, str]] = field(default_factory=list)
    confirmation_payload: Optional[dict[str, Any]] = None
    verification_stale_terms: list[str] = field(default_factory=list)

    def as_dict(self) -> dict[str, Any]:
        return {
            "intent": {
                "intent_type": self.intent.intent_type.value,
                "old_value": self.intent.old_value,
                "new_value": self.intent.new_value,
                "target_hint": self.intent.target_hint,
                "confidence": self.intent.confidence,
                "requires_confirmation": self.intent.requires_confirmation,
            },
            "applied": self.applied,
            "requires_confirmation": self.requires_confirmation,
            "affected_records": [
                {
                    "table": record.table,
                    "id": record.id,
                    "action": record.action,
                    "title": record.title,
                }
                for record in self.affected_records
            ],
            "corrections": self.corrections,
            "errors": self.errors,
            "confirmation_payload": self.confirmation_payload,
            "verification_stale_terms": self.verification_stale_terms,
        }


class MemoryCorrectionRepository(Protocol):
    async def list_long_term_memory(
        self,
        limit: int = 50,
        memory_type: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        pass

    async def update_long_term_memory(
        self,
        memory_id: str,
        **updates: object,
    ) -> Optional[dict]:
        pass

    async def deactivate_long_term_memory(self, memory_id: str) -> Optional[dict]:
        pass

    async def list_entities(
        self,
        limit: int = 50,
        entity_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
        normalized_name: Optional[str] = None,
    ) -> list[dict]:
        pass

    async def update_entity(self, entity_id: str, **updates: object) -> Optional[dict]:
        pass

    async def deactivate_entity(self, entity_id: str) -> Optional[dict]:
        pass

    async def create_memory_correction(self, correction: dict) -> dict:
        pass


@dataclass(frozen=True)
class TableSpec:
    table: str
    list_method: str
    update_method: str
    deactivate_method: str
    text_fields: tuple[str, ...]
    correction_type: str


TABLE_SPECS = (
    TableSpec(
        table="long_term_memory",
        list_method="list_long_term_memory",
        update_method="update_long_term_memory",
        deactivate_method="deactivate_long_term_memory",
        text_fields=("content",),
        correction_type="other",
    ),
    TableSpec(
        table="entities",
        list_method="list_entities",
        update_method="update_entity",
        deactivate_method="deactivate_entity",
        text_fields=("display_name", "normalized_name", "aliases", "relationship", "summary"),
        correction_type="entity_name",
    ),
    TableSpec(
        table="entity_events",
        list_method="list_entity_events",
        update_method="update_entity_event",
        deactivate_method="deactivate_entity_event",
        text_fields=("title", "content"),
        correction_type="entity_relationship",
    ),
    TableSpec(
        table="personal_rules",
        list_method="list_personal_rules",
        update_method="update_personal_rule",
        deactivate_method="deactivate_personal_rule",
        text_fields=("title", "rule_text", "trigger_keywords"),
        correction_type="rule_detail",
    ),
    TableSpec(
        table="plans",
        list_method="list_plans",
        update_method="update_plan",
        deactivate_method="deactivate_plan",
        text_fields=("title", "description", "desired_outcome"),
        correction_type="plan_detail",
    ),
    TableSpec(
        table="plan_milestones",
        list_method="list_plan_milestones",
        update_method="update_plan_milestone",
        deactivate_method="deactivate_plan_milestone",
        text_fields=("title", "description"),
        correction_type="plan_detail",
    ),
    TableSpec(
        table="open_threads",
        list_method="list_open_threads",
        update_method="update_open_thread",
        deactivate_method="delete_open_thread",
        text_fields=("title", "summary"),
        correction_type="other",
    ),
)

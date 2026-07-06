from typing import Optional

from app.models.pagination import decode_offset_cursor, paginate_rows

ENTITIES_TABLE = "entities"
ENTITY_EVENTS_TABLE = "entity_events"
PERSONAL_RULES_TABLE = "personal_rules"
PLANS_TABLE = "plans"
PLAN_MILESTONES_TABLE = "plan_milestones"

ENTITY_SELECT = (
    "id,entity_type,display_name,normalized_name,aliases,relationship,summary,"
    "source_conversation_id,source_message_id,source_memory_id,importance,status,"
    "active,metadata,first_seen_at,last_seen_at,created_at,updated_at"
)
ENTITY_EVENT_SELECT = (
    "id,entity_id,event_type,title,content,occurred_at,source_conversation_id,"
    "source_message_id,source_memory_id,importance,active,metadata,created_at,"
    "updated_at"
)
PERSONAL_RULE_SELECT = (
    "id,rule_type,title,rule_text,trigger_keywords,enforcement_style,"
    "source_conversation_id,source_message_id,source_memory_id,priority,status,"
    "active,starts_at,ends_at,last_checked_at,metadata,created_at,updated_at"
)
PLAN_SELECT = (
    "id,plan_type,title,description,desired_outcome,primary_entity_id,source_conversation_id,"
    "source_message_id,source_memory_id,priority,status,active,start_date,"
    "target_date,completed_at,last_reviewed_at,metadata,created_at,updated_at"
)
PLAN_MILESTONE_SELECT = (
    "id,plan_id,title,description,milestone_type,target_date,completed_at,"
    "source_conversation_id,source_message_id,source_memory_id,priority,status,"
    "active,metadata,created_at,updated_at"
)


class StructuredMemoryRepository:
    def __init__(self, store: object) -> None:
        self.store = store

    async def _list_table_paged(
        self,
        *,
        table: str,
        select: str,
        filters: dict[str, object],
        order: str,
        limit: int,
        cursor: Optional[str] = None,
    ) -> tuple[list[dict], Optional[str], bool]:
        offset = decode_offset_cursor(cursor)
        rows = await self.store._list_records(
            table,
            select=select,
            filters=filters,
            order=order,
            limit=limit + 1,
            offset=offset,
        )
        return paginate_rows(rows, limit=limit, offset=offset)

    async def create_entity(self, entity: dict) -> dict:
        return await self.store._create_record(ENTITIES_TABLE, entity, ENTITY_SELECT)

    async def list_entities(
        self,
        limit: int = 50,
        entity_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
        normalized_name: Optional[str] = None,
    ) -> list[dict]:
        items, _, _ = await self.list_entities_paged(
            limit=limit,
            entity_type=entity_type,
            status=status,
            active=active,
            normalized_name=normalized_name,
        )
        return items

    async def list_entities_paged(
        self,
        limit: int = 50,
        entity_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
        normalized_name: Optional[str] = None,
        cursor: Optional[str] = None,
    ) -> tuple[list[dict], Optional[str], bool]:
        return await self._list_table_paged(
            table=ENTITIES_TABLE,
            select=ENTITY_SELECT,
            filters={
                "entity_type": entity_type,
                "status": status,
                "active": active,
                "normalized_name": normalized_name,
            },
            order="importance.desc,last_seen_at.desc,updated_at.desc",
            limit=limit,
            cursor=cursor,
        )

    async def update_entity(self, entity_id: str, **updates: object) -> Optional[dict]:
        return await self.store._update_record(
            ENTITIES_TABLE,
            entity_id,
            updates=updates,
            select=ENTITY_SELECT,
            empty_detail="At least one entity field must be provided.",
        )

    async def deactivate_entity(self, entity_id: str) -> Optional[dict]:
        return await self.update_entity(entity_id, active=False, status="inactive")

    async def create_entity_event(self, event: dict) -> dict:
        return await self.store._create_record(
            ENTITY_EVENTS_TABLE,
            event,
            ENTITY_EVENT_SELECT,
        )

    async def list_entity_events(
        self,
        limit: int = 50,
        entity_id: Optional[str] = None,
        event_type: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        return await self.store._list_records(
            ENTITY_EVENTS_TABLE,
            select=ENTITY_EVENT_SELECT,
            filters={
                "entity_id": entity_id,
                "event_type": event_type,
                "active": active,
            },
            order="importance.desc,created_at.desc",
            limit=limit,
        )

    async def update_entity_event(
        self,
        event_id: str,
        **updates: object,
    ) -> Optional[dict]:
        return await self.store._update_record(
            ENTITY_EVENTS_TABLE,
            event_id,
            updates=updates,
            select=ENTITY_EVENT_SELECT,
            empty_detail="At least one entity event field must be provided.",
        )

    async def deactivate_entity_event(self, event_id: str) -> Optional[dict]:
        return await self.update_entity_event(event_id, active=False)

    async def create_personal_rule(self, rule: dict) -> dict:
        return await self.store._create_record(
            PERSONAL_RULES_TABLE,
            rule,
            PERSONAL_RULE_SELECT,
        )

    async def list_personal_rules(
        self,
        limit: int = 50,
        rule_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        items, _, _ = await self.list_personal_rules_paged(
            limit=limit,
            rule_type=rule_type,
            status=status,
            active=active,
        )
        return items

    async def list_personal_rules_paged(
        self,
        limit: int = 50,
        rule_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
        cursor: Optional[str] = None,
    ) -> tuple[list[dict], Optional[str], bool]:
        return await self._list_table_paged(
            table=PERSONAL_RULES_TABLE,
            select=PERSONAL_RULE_SELECT,
            filters={
                "rule_type": rule_type,
                "status": status,
                "active": active,
            },
            order="priority.desc,updated_at.desc",
            limit=limit,
            cursor=cursor,
        )

    async def update_personal_rule(
        self,
        rule_id: str,
        **updates: object,
    ) -> Optional[dict]:
        return await self.store._update_record(
            PERSONAL_RULES_TABLE,
            rule_id,
            updates=updates,
            select=PERSONAL_RULE_SELECT,
            empty_detail="At least one personal rule field must be provided.",
        )

    async def deactivate_personal_rule(self, rule_id: str) -> Optional[dict]:
        return await self.update_personal_rule(
            rule_id,
            active=False,
            status="archived",
        )

    async def create_plan(self, plan: dict) -> dict:
        return await self.store._create_record(PLANS_TABLE, plan, PLAN_SELECT)

    async def list_plans(
        self,
        limit: int = 50,
        plan_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        items, _, _ = await self.list_plans_paged(
            limit=limit,
            plan_type=plan_type,
            status=status,
            active=active,
        )
        return items

    async def list_plans_paged(
        self,
        limit: int = 50,
        plan_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
        cursor: Optional[str] = None,
    ) -> tuple[list[dict], Optional[str], bool]:
        return await self._list_table_paged(
            table=PLANS_TABLE,
            select=PLAN_SELECT,
            filters={
                "plan_type": plan_type,
                "status": status,
                "active": active,
            },
            order="priority.desc,target_date.asc,updated_at.desc",
            limit=limit,
            cursor=cursor,
        )

    async def update_plan(self, plan_id: str, **updates: object) -> Optional[dict]:
        return await self.store._update_record(
            PLANS_TABLE,
            plan_id,
            updates=updates,
            select=PLAN_SELECT,
            empty_detail="At least one plan field must be provided.",
        )

    async def deactivate_plan(self, plan_id: str) -> Optional[dict]:
        return await self.update_plan(plan_id, active=False, status="archived")

    async def create_plan_milestone(self, milestone: dict) -> dict:
        return await self.store._create_record(
            PLAN_MILESTONES_TABLE,
            milestone,
            PLAN_MILESTONE_SELECT,
        )

    async def list_plan_milestones(
        self,
        limit: int = 50,
        plan_id: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        return await self.store._list_records(
            PLAN_MILESTONES_TABLE,
            select=PLAN_MILESTONE_SELECT,
            filters={
                "plan_id": plan_id,
                "status": status,
                "active": active,
            },
            order="priority.desc,target_date.asc,updated_at.desc",
            limit=limit,
        )

    async def update_plan_milestone(
        self,
        milestone_id: str,
        **updates: object,
    ) -> Optional[dict]:
        return await self.store._update_record(
            PLAN_MILESTONES_TABLE,
            milestone_id,
            updates=updates,
            select=PLAN_MILESTONE_SELECT,
            empty_detail="At least one plan milestone field must be provided.",
        )

    async def deactivate_plan_milestone(self, milestone_id: str) -> Optional[dict]:
        return await self.update_plan_milestone(
            milestone_id,
            active=False,
            status="canceled",
        )

    async def delete_entity(self, entity_id: str) -> bool:
        return await self._delete_row(ENTITIES_TABLE, entity_id)

    async def delete_entity_event(self, event_id: str) -> bool:
        return await self._delete_row(ENTITY_EVENTS_TABLE, event_id)

    async def delete_personal_rule(self, rule_id: str) -> bool:
        return await self._delete_row(PERSONAL_RULES_TABLE, rule_id)

    async def delete_plan(self, plan_id: str) -> bool:
        return await self._delete_row(PLANS_TABLE, plan_id)

    async def delete_plan_milestone(self, milestone_id: str) -> bool:
        return await self._delete_row(PLAN_MILESTONES_TABLE, milestone_id)

    async def _delete_row(self, table: str, record_id: str) -> bool:
        try:
            return await self.store._delete_record(table, record_id)
        except Exception:
            return False

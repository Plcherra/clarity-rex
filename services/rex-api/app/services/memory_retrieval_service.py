import asyncio
from typing import Optional

from app.services.memory_retrieval_ranker import (
    RELEVANT_MEMORY_SCAN_LIMIT,
    STRUCTURED_MEMORY_DIRECT_LIMIT,
    STRUCTURED_MEMORY_RELATED_LIMIT,
    STRUCTURED_MEMORY_SCAN_LIMIT,
    MemoryRetrievalRanker,
)


class MemoryRetrievalService:
    def __init__(
        self,
        memory_store: object,
        ranker: Optional[MemoryRetrievalRanker] = None,
    ) -> None:
        self.memory_store = memory_store
        self.ranker = ranker or MemoryRetrievalRanker()

    async def get_long_term_memory(
        self,
        query: Optional[str] = None,
        limit: int = 8,
    ) -> list[dict]:
        if query is None:
            return await self.memory_store.list_long_term_memory(
                limit=limit,
                active=True,
            )

        return await self.get_relevant_memories(query=query, limit=limit)

    async def get_relevant_memories(self, query: str, limit: int = 8) -> list[dict]:
        memories = await self.memory_store.list_long_term_memory(
            limit=max(RELEVANT_MEMORY_SCAN_LIMIT, limit),
            active=True,
        )
        query_terms = self.ranker.expanded_terms(query)
        scored_memories = []

        for memory in memories:
            scored_memory = self.ranker.score_memory(memory, query_terms)
            if scored_memory is not None:
                scored_memories.append(scored_memory)

        scored_memories.sort(
            key=lambda memory: (
                memory.get("relevance_score", 0),
                memory.get("importance", 0),
                str(
                    memory.get("last_accessed_at")
                    or memory.get("created_at")
                    or ""
                ),
            ),
            reverse=True,
        )
        scored_memories = self.ranker.filter_stale_corrected_memories(
            scored_memories,
        )
        return scored_memories[:limit]

    async def get_structured_memory_context(self, query: str) -> dict:
        (
            entities,
            entity_events,
            personal_rules,
            plans,
            plan_milestones,
        ) = await asyncio.gather(
            self.memory_store.list_entities(
                limit=STRUCTURED_MEMORY_SCAN_LIMIT,
                active=True,
            ),
            self.memory_store.list_entity_events(
                limit=STRUCTURED_MEMORY_SCAN_LIMIT,
                active=True,
            ),
            self.memory_store.list_personal_rules(
                limit=STRUCTURED_MEMORY_SCAN_LIMIT,
                active=True,
            ),
            self.memory_store.list_plans(
                limit=STRUCTURED_MEMORY_SCAN_LIMIT,
                active=True,
            ),
            self.memory_store.list_plan_milestones(
                limit=STRUCTURED_MEMORY_SCAN_LIMIT,
                active=True,
            ),
        )

        query_terms = self.ranker.expanded_terms(query)
        selected_entities = self.ranker.rank_structured_records(
            entities,
            query_terms=query_terms,
            text_fields=("display_name", "normalized_name", "relationship", "summary"),
            list_fields=("aliases",),
            weight_field="importance",
            status_values={"active"},
            limit=STRUCTURED_MEMORY_DIRECT_LIMIT,
        )
        selected_entities = self.ranker.merge_related_records(
            selected_entities,
            self._self_profile_entities(entities, query),
        )
        selected_rules = self.ranker.rank_structured_records(
            personal_rules,
            query_terms=query_terms,
            text_fields=("title", "rule_text", "rule_type"),
            list_fields=("trigger_keywords",),
            weight_field="priority",
            status_values={"active"},
            include_high_priority=True,
            limit=STRUCTURED_MEMORY_DIRECT_LIMIT,
        )
        selected_plans = self.ranker.rank_structured_records(
            plans,
            query_terms=query_terms,
            text_fields=("title", "description", "desired_outcome", "plan_type"),
            weight_field="priority",
            status_values={"active", "paused"},
            include_high_priority=True,
            limit=STRUCTURED_MEMORY_DIRECT_LIMIT,
        )

        selected_entity_ids = {str(entity.get("id")) for entity in selected_entities}
        selected_plan_ids = {str(plan.get("id")) for plan in selected_plans}
        selected_entity_ids.update(
            str(plan.get("primary_entity_id"))
            for plan in selected_plans
            if plan.get("primary_entity_id")
        )
        related_entities = self.ranker.related_records(
            entities,
            link_field="id",
            selected_ids=selected_entity_ids,
            weight_field="importance",
            status_values={"active"},
            limit=STRUCTURED_MEMORY_RELATED_LIMIT,
        )
        selected_entities = self.ranker.merge_related_records(
            selected_entities,
            related_entities,
        )
        selected_entity_ids = {str(entity.get("id")) for entity in selected_entities}
        related_plans = self.ranker.related_records(
            plans,
            link_field="primary_entity_id",
            selected_ids=selected_entity_ids,
            weight_field="priority",
            status_values={"active", "paused"},
            limit=STRUCTURED_MEMORY_RELATED_LIMIT,
        )
        selected_plans = self.ranker.merge_related_records(
            selected_plans,
            related_plans,
        )
        selected_plan_ids.update(
            str(plan.get("id"))
            for plan in selected_plans
            if plan.get("id")
        )

        related_entity_events = self.ranker.related_records(
            entity_events,
            link_field="entity_id",
            selected_ids=selected_entity_ids,
            weight_field="importance",
            limit=STRUCTURED_MEMORY_RELATED_LIMIT,
        )
        related_milestones = self.ranker.related_records(
            plan_milestones,
            link_field="plan_id",
            selected_ids=selected_plan_ids,
            weight_field="priority",
            status_values={"open", "in_progress"},
            limit=STRUCTURED_MEMORY_RELATED_LIMIT,
        )

        return {
            "entities": selected_entities,
            "entity_events": related_entity_events,
            "personal_rules": selected_rules,
            "plans": selected_plans,
            "plan_milestones": related_milestones,
        }

    def _self_profile_entities(self, entities: list[dict], query: str) -> list[dict]:
        if not self._is_self_profile_query(query):
            return []
        matches = []
        for entity in entities:
            if not self._is_self_entity(entity):
                continue
            matches.append(
                {
                    **entity,
                    "relevance_reason": "Included self profile structured memory.",
                }
            )
        matches.sort(
            key=lambda entity: (
                int(entity.get("importance") or 0),
                str(entity.get("updated_at") or entity.get("created_at") or ""),
            ),
            reverse=True,
        )
        return matches[:1]

    def _is_self_profile_query(self, query: str) -> bool:
        normalized = f" {query.lower()} "
        normalized = " ".join(normalized.split())
        return any(
            phrase in normalized
            for phrase in (
                "what do you know",
                "what do you remember",
                "what does clarity know",
                "what does clarity remember",
                "check what clarity knows",
                "check what clarity know",
                "show me what clarity knows",
                "what does rex know",
                "what does rex remember",
                "what have you saved",
                "what do you have saved",
                "what information do you have",
                "what information do you know",
                "about me",
                "about myself",
                "know about me",
                "know about myself",
                "clarity know about me",
                "clarity knows about me",
                "what do you know about me",
                "what does clarity know about me",
            )
        )

    def _is_self_entity(self, entity: dict) -> bool:
        if entity.get("entity_type") != "person":
            return False
        if str(entity.get("relationship") or "").strip().lower() == "self":
            return True
        metadata = entity.get("metadata")
        return (
            isinstance(metadata, dict)
            and str(metadata.get("entity_direction") or "").strip().lower() == "self"
        )

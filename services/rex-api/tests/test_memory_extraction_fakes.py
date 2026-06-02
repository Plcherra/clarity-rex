class FakeExtractionAIService:
    def __init__(self, response):
        self.response = response
        self.messages = []

    async def generate_response(self, messages):
        self.messages = messages
        if isinstance(self.response, Exception):
            raise self.response
        return self.response


class FakeMemoryStore:
    def __init__(self, existing_memories=None):
        self.existing_memories = existing_memories or []
        self.saved_memories = []
        self.updated_memories = []
        self.deactivated_memory_ids = []
        self.created_memory_corrections = []
        self.created_entities = []
        self.created_entity_events = []
        self.created_rules = []
        self.created_plans = []
        self.created_milestones = []
        self.created_commitments = []
        self.created_memory_candidates = []
        self.relevant_queries = []

    async def get_relevant_memories(self, query, limit=8):
        self.relevant_queries.append({"query": query, "limit": limit})
        return self.existing_memories[:limit]

    async def save_long_term_memory(
        self,
        memory_type,
        content,
        source_conversation_id=None,
        source_message_id=None,
        importance=3,
    ):
        memory = {
            "id": f"memory-{len(self.saved_memories) + 1}",
            "memory_type": memory_type,
            "content": content,
            "source_conversation_id": source_conversation_id,
            "source_message_id": source_message_id,
            "importance": importance,
            "active": True,
        }
        self.saved_memories.append(memory)
        return memory

    async def update_long_term_memory(
        self,
        memory_id,
        memory_type=None,
        content=None,
        importance=None,
        active=None,
        superseded_by=None,
        confidence=None,
        correction_group=None,
        metadata=None,
    ):
        for memory in self.existing_memories:
            if memory["id"] != memory_id:
                continue
            if memory_type is not None:
                memory["memory_type"] = memory_type
            if content is not None:
                memory["content"] = content
            if importance is not None:
                memory["importance"] = importance
            if active is not None:
                memory["active"] = active
            if superseded_by is not None:
                memory["superseded_by"] = superseded_by
            if confidence is not None:
                memory["confidence"] = confidence
            if correction_group is not None:
                memory["correction_group"] = correction_group
            if metadata is not None:
                memory["metadata"] = metadata
            self.updated_memories.append(memory.copy())
            return memory
        return None

    async def deactivate_long_term_memory(self, memory_id):
        self.deactivated_memory_ids.append(memory_id)
        for memory in self.existing_memories:
            if memory["id"] == memory_id:
                memory["active"] = False
                return True
        return False

    async def create_memory_correction(self, correction):
        row = {
            "id": f"correction-{len(self.created_memory_corrections) + 1}",
            **correction,
        }
        self.created_memory_corrections.append(row)
        return row

    async def create_memory_candidate(self, payload):
        row = {
            "id": f"candidate-{len(self.created_memory_candidates) + 1}",
            "status": "pending",
            "decision": None,
            "verification": None,
            **payload,
        }
        self.created_memory_candidates.append(row)
        self._mirror_candidate_payload_for_legacy_assertions(row)
        return row

    def _mirror_candidate_payload_for_legacy_assertions(self, row):
        candidate_type = row.get("candidate_type")
        payload = dict(row.get("payload") or {})
        discipline = payload.get("memory_discipline") or {}
        action = discipline.get("action")
        target_id = discipline.get("target_id")
        payload.pop("memory_discipline", None)
        if candidate_type == "entity":
            if action == "update_entity" and target_id:
                _update(self.created_entities, target_id, payload)
            else:
                self.created_entities.append(
                    {"id": f"entity-{len(self.created_entities) + 1}", **payload}
                )
        elif candidate_type == "entity_event":
            self.created_entity_events.append(
                {"id": f"event-{len(self.created_entity_events) + 1}", **payload}
            )
        elif candidate_type == "personal_rule":
            if action == "update_rule" and target_id:
                _update(self.created_rules, target_id, payload)
            else:
                self.created_rules.append(
                    {"id": f"rule-{len(self.created_rules) + 1}", **payload}
                )
        elif candidate_type == "plan":
            if action == "update_plan" and target_id:
                _update(self.created_plans, target_id, payload)
            else:
                self.created_plans.append(
                    {"id": f"plan-{len(self.created_plans) + 1}", **payload}
                )
        elif candidate_type == "plan_milestone":
            if action == "update_milestone" and target_id:
                _update(self.created_milestones, target_id, payload)
            else:
                self.created_milestones.append(
                    {
                        "id": f"milestone-{len(self.created_milestones) + 1}",
                        **payload,
                    }
                )
        elif candidate_type == "commitment":
            if action == "update_commitment" and target_id:
                _update(self.created_commitments, target_id, payload)
            else:
                self.created_commitments.append(
                    {
                        "id": f"commitment-{len(self.created_commitments) + 1}",
                        **payload,
                    }
                )

    async def create_entity(self, payload):
        entity = {"id": f"entity-{len(self.created_entities) + 1}", **payload}
        self.created_entities.append(entity)
        return entity

    async def list_entities(
        self,
        limit=50,
        entity_type=None,
        status=None,
        active=None,
        normalized_name=None,
    ):
        rows = self.created_entities
        if entity_type is not None:
            rows = [row for row in rows if row.get("entity_type") == entity_type]
        if status is not None:
            rows = [row for row in rows if row.get("status") == status]
        if active is not None:
            rows = [row for row in rows if row.get("active") is active]
        if normalized_name is not None:
            rows = [
                row for row in rows if row.get("normalized_name") == normalized_name
            ]
        return rows[:limit]

    async def update_entity(self, entity_id, **updates):
        return _update(self.created_entities, entity_id, updates)

    async def create_entity_event(self, payload):
        event = {"id": f"event-{len(self.created_entity_events) + 1}", **payload}
        self.created_entity_events.append(event)
        return event

    async def create_personal_rule(self, payload):
        rule = {"id": f"rule-{len(self.created_rules) + 1}", **payload}
        self.created_rules.append(rule)
        return rule

    async def list_personal_rules(
        self,
        limit=50,
        rule_type=None,
        status=None,
        active=None,
    ):
        rows = self.created_rules
        if rule_type is not None:
            rows = [row for row in rows if row.get("rule_type") == rule_type]
        if status is not None:
            rows = [row for row in rows if row.get("status") == status]
        if active is not None:
            rows = [row for row in rows if row.get("active") is active]
        return rows[:limit]

    async def update_personal_rule(self, rule_id, **updates):
        return _update(self.created_rules, rule_id, updates)

    async def create_plan(self, payload):
        plan = {"id": f"plan-{len(self.created_plans) + 1}", **payload}
        self.created_plans.append(plan)
        return plan

    async def list_plans(self, limit=50, plan_type=None, status=None, active=None):
        rows = self.created_plans
        if plan_type is not None:
            rows = [row for row in rows if row.get("plan_type") == plan_type]
        if status is not None:
            rows = [row for row in rows if row.get("status") == status]
        if active is not None:
            rows = [row for row in rows if row.get("active") is active]
        return rows[:limit]

    async def update_plan(self, plan_id, **updates):
        return _update(self.created_plans, plan_id, updates)

    async def create_plan_milestone(self, payload):
        milestone = {"id": f"milestone-{len(self.created_milestones) + 1}", **payload}
        self.created_milestones.append(milestone)
        return milestone

    async def list_plan_milestones(
        self,
        limit=50,
        plan_id=None,
        status=None,
        active=None,
    ):
        rows = self.created_milestones
        if plan_id is not None:
            rows = [row for row in rows if row.get("plan_id") == plan_id]
        if status is not None:
            rows = [row for row in rows if row.get("status") == status]
        if active is not None:
            rows = [row for row in rows if row.get("active") is active]
        return rows[:limit]

    async def create_commitment(self, payload):
        commitment = {
            "id": f"commitment-{len(self.created_commitments) + 1}",
            **payload,
        }
        self.created_commitments.append(commitment)
        return commitment

    async def list_commitments(
        self,
        limit=50,
        commitment_type=None,
        plan_id=None,
        entity_id=None,
        status=None,
        active=None,
    ):
        rows = self.created_commitments
        if commitment_type is not None:
            rows = [
                row for row in rows if row.get("commitment_type") == commitment_type
            ]
        if plan_id is not None:
            rows = [row for row in rows if row.get("plan_id") == plan_id]
        if entity_id is not None:
            rows = [row for row in rows if row.get("entity_id") == entity_id]
        if status is not None:
            rows = [row for row in rows if row.get("status") == status]
        if active is not None:
            rows = [row for row in rows if row.get("active") is active]
        return rows[:limit]

    async def update_commitment(self, commitment_id, **updates):
        return _update(self.created_commitments, commitment_id, updates)


def _update(rows, row_id, updates):
    for row in rows:
        if row["id"] == row_id:
            row.update(updates)
            return row
    return None

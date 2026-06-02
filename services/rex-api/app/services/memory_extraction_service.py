from difflib import SequenceMatcher
from typing import Any, Optional, Protocol

from app.models.commitment import CommitmentCreateRequest
from app.models.entity import EntityCreateRequest
from app.models.memory_discipline import (
    MemoryCandidateKind,
)
from app.models.personal_rule import PersonalRuleCreateRequest
from app.models.plan import PlanCreateRequest, PlanMilestoneCreateRequest
from app.services.ai_service import AIService
from app.services.commitment_service import CommitmentService
from app.services.entity_normalization_service import EntityNormalizationService
from app.services.entity_service import EntityService
from app.services.memory_candidate_writer import MemoryCandidateWriter
from app.services.memory_discipline_service import MemoryDisciplineService
from app.services.memory_extraction_parser import (
    MemoryExtractionParser,
)
from app.services.memory_extraction_prompt import MEMORY_EXTRACTION_PROMPT
from app.services.memory_reference_resolver import MemoryReferenceResolver
from app.services.memory_structured_candidate_normalizer import (
    MemoryStructuredCandidateNormalizer,
    normalized_text,
)
from app.services.plan_service import PlanService
from app.services.rule_service import RuleService

DUPLICATE_SIMILARITY_THRESHOLD = 0.86
DUPLICATE_TOKEN_OVERLAP_THRESHOLD = 0.72


class MemoryStore(Protocol):
    async def get_relevant_memories(self, query: str, limit: int = 8) -> list[dict]:
        pass

    async def save_long_term_memory(
        self,
        memory_type: str,
        content: str,
        source_conversation_id: Optional[str] = None,
        source_message_id: Optional[str] = None,
        importance: int = 3,
    ) -> dict:
        pass

    async def update_long_term_memory(
        self,
        memory_id: str,
        memory_type: Optional[str] = None,
        content: Optional[str] = None,
        importance: Optional[int] = None,
        active: Optional[bool] = None,
    ) -> Optional[dict]:
        pass

    async def deactivate_long_term_memory(self, memory_id: str) -> bool:
        pass

    async def create_memory_correction(self, correction: dict) -> dict:
        pass

    async def create_entity(self, payload: dict) -> dict:
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

    async def create_entity_event(self, payload: dict) -> dict:
        pass

    async def create_personal_rule(self, payload: dict) -> dict:
        pass

    async def update_personal_rule(self, rule_id: str, **updates: object) -> dict:
        pass

    async def create_plan(self, payload: dict) -> dict:
        pass

    async def list_plans(
        self,
        limit: int = 50,
        plan_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        pass

    async def create_plan_milestone(self, payload: dict) -> dict:
        pass

    async def create_commitment(self, payload: dict) -> dict:
        pass

    async def create_memory_candidate(self, payload: dict) -> dict:
        pass


class MemoryExtractionService:
    def __init__(
        self,
        ai_service: AIService,
        memory_service: MemoryStore,
        memory_discipline_service: Optional[MemoryDisciplineService] = None,
    ) -> None:
        self.ai_service = ai_service
        self.memory_service = memory_service
        self.entity_service = EntityService(memory_service)
        self.rule_service = RuleService(memory_service)
        self.plan_service = PlanService(memory_service)
        self.commitment_service = CommitmentService(memory_service)
        self.entity_normalization_service = EntityNormalizationService()
        self.parser = MemoryExtractionParser()
        self.structured_normalizer = MemoryStructuredCandidateNormalizer()
        self.reference_resolver = MemoryReferenceResolver(
            memory_service,
            self.entity_normalization_service,
        )
        self.memory_discipline_service = (
            memory_discipline_service or MemoryDisciplineService(memory_service)
        )
        self.candidate_writer = MemoryCandidateWriter(
            memory_service,
            self.memory_discipline_service,
        )

    async def extract_and_save(
        self,
        conversation_id: str,
        user_message: dict,
        assistant_message: dict,
        brain_metadata: Optional[dict[str, Any]] = None,
    ) -> list[dict]:
        try:
            raw_response = await self.ai_service.generate_response(
                [
                    {"role": "system", "content": MEMORY_EXTRACTION_PROMPT},
                    {
                        "role": "user",
                        "content": self.parser.turn_payload(
                            user_message,
                            assistant_message,
                        ),
                    },
                ]
            )
        except Exception:
            return []

        extraction_payload = self.parser.parse_extraction_payload(raw_response)
        candidates = extraction_payload["memories"]
        pending_candidates = []

        for candidate in candidates:
            normalized = self.parser.normalize_candidate(candidate)
            if normalized is None:
                continue
            if await self._is_duplicate(normalized["content"]):
                continue

            pending = await self.candidate_writer.create_pending_memory_candidate(
                candidate_type="long_term_memory",
                payload={
                    "memory_type": normalized["memory_type"],
                    "content": normalized["content"],
                    "importance": normalized["importance"],
                    "metadata": {
                        "extraction_rationale": normalized["rationale"],
                    },
                },
                rationale=normalized["rationale"],
                conversation_id=conversation_id,
                user_message_id=str(user_message.get("id"))
                if user_message.get("id")
                else None,
                risk_level=self.candidate_writer.candidate_risk_level(
                    candidate_type="long_term_memory",
                    payload=normalized,
                ),
                brain_metadata=brain_metadata,
            )
            if pending:
                pending_candidates.append(pending)

        structured_memories = await self._save_structured_memories(
            extraction_payload["structured_memories"],
            conversation_id=conversation_id,
            user_message_id=str(user_message.get("id"))
            if user_message.get("id")
            else None,
            brain_metadata=brain_metadata,
        )
        pending_candidates.extend(structured_memories)

        return pending_candidates

    async def _save_structured_memories(
        self,
        structured_memories: dict[str, list[dict]],
        *,
        conversation_id: str,
        user_message_id: Optional[str],
        brain_metadata: Optional[dict[str, Any]] = None,
    ) -> list[dict]:
        saved: list[dict] = []
        entity_ids_by_key: dict[str, str] = {}
        plan_ids_by_key: dict[str, str] = {}
        await self.reference_resolver.load_existing_entity_keys(entity_ids_by_key)
        await self.reference_resolver.load_existing_plan_keys(plan_ids_by_key)

        for candidate in structured_memories.get("entities", []):
            normalized = self.structured_normalizer.normalize_entity(
                candidate,
                conversation_id=conversation_id,
                user_message_id=user_message_id,
            )
            if normalized is None:
                continue
            saved_entity = await self.candidate_writer.save_structured_candidate(
                kind=MemoryCandidateKind.ENTITY,
                payload=normalized["payload"],
                rationale=normalized["rationale"],
                fallback=lambda: self.candidate_writer.call_service_create(
                    self.entity_service.create_entity,
                    EntityCreateRequest(**normalized["payload"]),
                ),
                brain_metadata=brain_metadata,
            )
            if saved_entity:
                saved.append(saved_entity)

        for candidate in structured_memories.get("entity_events", []):
            await self.reference_resolver.resolve_entity_reference(
                candidate,
                entity_ids_by_key,
            )
            normalized = self.structured_normalizer.normalize_entity_event(
                candidate,
                conversation_id=conversation_id,
                user_message_id=user_message_id,
            )
            if normalized is None:
                continue
            saved_event = await self.candidate_writer.create_pending_memory_candidate(
                candidate_type="entity_event",
                payload=normalized["payload"],
                rationale=normalized["rationale"],
                conversation_id=conversation_id,
                user_message_id=user_message_id,
                risk_level=self.candidate_writer.candidate_risk_level(
                    candidate_type="entity_event",
                    payload=normalized["payload"],
                ),
                brain_metadata=brain_metadata,
            )
            if saved_event:
                saved.append(saved_event)

        for candidate in structured_memories.get("personal_rules", []):
            normalized = self.structured_normalizer.normalize_rule(
                candidate,
                conversation_id=conversation_id,
                user_message_id=user_message_id,
            )
            if normalized is None:
                continue
            saved_rule = await self.candidate_writer.save_structured_candidate(
                kind=MemoryCandidateKind.PERSONAL_RULE,
                payload=normalized["payload"],
                rationale=normalized["rationale"],
                fallback=lambda: self.candidate_writer.call_service_create(
                    self.rule_service.create_rule,
                    PersonalRuleCreateRequest(**normalized["payload"]),
                ),
                brain_metadata=brain_metadata,
            )
            if saved_rule:
                saved.append(saved_rule)

        for candidate in structured_memories.get("plans", []):
            await self.reference_resolver.resolve_entity_reference(
                candidate,
                entity_ids_by_key,
            )
            normalized = self.structured_normalizer.normalize_plan(
                candidate,
                conversation_id=conversation_id,
                user_message_id=user_message_id,
            )
            if normalized is None:
                continue
            saved_plan = await self.candidate_writer.save_structured_candidate(
                kind=MemoryCandidateKind.PLAN,
                payload=normalized["payload"],
                rationale=normalized["rationale"],
                fallback=lambda: self.candidate_writer.call_service_create(
                    self.plan_service.create_plan,
                    PlanCreateRequest(**normalized["payload"]),
                ),
                brain_metadata=brain_metadata,
            )
            if saved_plan:
                saved.append(saved_plan)

        for candidate in structured_memories.get("plan_milestones", []):
            await self.reference_resolver.resolve_plan_reference(
                candidate,
                plan_ids_by_key,
            )
            normalized = self.structured_normalizer.normalize_plan_milestone(
                candidate,
                conversation_id=conversation_id,
                user_message_id=user_message_id,
            )
            if normalized is None:
                continue
            saved_milestone = await self.candidate_writer.save_structured_candidate(
                kind=MemoryCandidateKind.PLAN_MILESTONE,
                payload=normalized["payload"],
                rationale=normalized["rationale"],
                fallback=lambda: self.candidate_writer.call_service_create(
                    self.plan_service.create_milestone,
                    PlanMilestoneCreateRequest(**normalized["payload"]),
                ),
                brain_metadata=brain_metadata,
            )
            if saved_milestone:
                saved.append(saved_milestone)

        for candidate in structured_memories.get("commitments", []):
            await self.reference_resolver.resolve_entity_reference(
                candidate,
                entity_ids_by_key,
            )
            await self.reference_resolver.resolve_plan_reference(
                candidate,
                plan_ids_by_key,
            )
            normalized = self.structured_normalizer.normalize_commitment(
                candidate,
                conversation_id=conversation_id,
                user_message_id=user_message_id,
            )
            if normalized is None:
                continue
            saved_commitment = await self.candidate_writer.save_structured_candidate(
                kind=MemoryCandidateKind.COMMITMENT,
                payload=normalized["payload"],
                rationale=normalized["rationale"],
                fallback=lambda: self.candidate_writer.call_service_create(
                    self.commitment_service.create_commitment,
                    CommitmentCreateRequest(**normalized["payload"]),
                ),
                brain_metadata=brain_metadata,
            )
            if saved_commitment:
                saved.append(saved_commitment)

        return saved

    async def _is_duplicate(self, content: str) -> bool:
        existing_memories = await self.memory_service.get_relevant_memories(
            query=content,
            limit=20,
        )
        normalized_content = normalized_text(content)
        content_tokens = set(normalized_content.split())

        for memory in existing_memories:
            existing_content = str(memory.get("content", ""))
            normalized_existing = normalized_text(existing_content)
            if not normalized_existing:
                continue
            if normalized_existing == normalized_content:
                return True

            similarity = SequenceMatcher(
                None,
                normalized_content,
                normalized_existing,
            ).ratio()
            existing_tokens = set(normalized_existing.split())
            token_overlap = len(content_tokens & existing_tokens) / max(
                len(content_tokens | existing_tokens),
                1,
            )

            if (
                similarity >= DUPLICATE_SIMILARITY_THRESHOLD
                or token_overlap >= DUPLICATE_TOKEN_OVERLAP_THRESHOLD
            ):
                return True

        return False

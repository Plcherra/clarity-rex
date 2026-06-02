from typing import Optional

from app.config import Settings, get_settings
from app.services.conversation_repository import ConversationRepository
from app.services.long_term_memory_repository import LongTermMemoryRepository
from app.services.memory_confirmation_facade import MemoryConfirmationFacade
from app.services.memory_confirmation_repository import MemoryConfirmationRepository
from app.services.memory_candidate_repository import MemoryCandidateRepository
from app.services.memory_candidate_review_session_facade import MemoryCandidateReviewSessionFacade
from app.services.memory_errors import MemoryServiceError
from app.services.memory_retrieval_service import MemoryRetrievalService
from app.services.structured_memory_repository import StructuredMemoryRepository
from app.services.supabase_memory_transport import SupabaseMemoryTransport


class SupabaseMemoryService(SupabaseMemoryTransport, MemoryConfirmationFacade, MemoryCandidateReviewSessionFacade):
    def __init__(
        self,
        settings: Optional[Settings] = None,
        user_id: Optional[str] = None,
        access_token: Optional[str] = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.user_id = user_id
        self.access_token = access_token
        self.conversation_repository = ConversationRepository(self)
        self.long_term_memory_repository = LongTermMemoryRepository(self)
        self.memory_retrieval_service = MemoryRetrievalService(self)
        self.structured_memory_repository = StructuredMemoryRepository(self)
        self.memory_candidate_repository = MemoryCandidateRepository(self)
        self.memory_confirmation_repository = MemoryConfirmationRepository(self)

    def _get_conversation_repository(self) -> ConversationRepository:
        repository = getattr(self, "conversation_repository", None)
        if repository is None:
            repository = ConversationRepository(self)
            self.conversation_repository = repository
        return repository

    def _get_long_term_memory_repository(self) -> LongTermMemoryRepository:
        repository = getattr(self, "long_term_memory_repository", None)
        if repository is None:
            repository = LongTermMemoryRepository(self)
            self.long_term_memory_repository = repository
        return repository

    def _get_memory_retrieval_service(self) -> MemoryRetrievalService:
        service = getattr(self, "memory_retrieval_service", None)
        if service is None:
            service = MemoryRetrievalService(self)
            self.memory_retrieval_service = service
        return service

    def _get_structured_memory_repository(self) -> StructuredMemoryRepository:
        repository = getattr(self, "structured_memory_repository", None)
        if repository is None:
            repository = StructuredMemoryRepository(self)
            self.structured_memory_repository = repository
        return repository

    def _get_memory_candidate_repository(self) -> MemoryCandidateRepository:
        repository = getattr(self, "memory_candidate_repository", None)
        if repository is None:
            repository = MemoryCandidateRepository(self)
            self.memory_candidate_repository = repository
        return repository

    async def create_conversation(self) -> str:
        return await self._get_conversation_repository().create_conversation()

    async def create_conversation_record(self) -> dict:
        return await self._get_conversation_repository().create_conversation_record()

    async def list_conversations(self, limit: int = 50) -> list[dict]:
        return await self._get_conversation_repository().list_conversations(limit=limit)

    async def conversation_exists(self, conversation_id: str) -> bool:
        return await self._get_conversation_repository().conversation_exists(
            conversation_id,
        )

    async def save_message(self, conversation_id: str, role: str, content: str) -> dict:
        return await self._get_conversation_repository().save_message(
            conversation_id,
            role,
            content,
        )

    async def get_recent_messages(
        self,
        conversation_id: str,
        limit: int = 20,
    ) -> list[dict]:
        return await self._get_conversation_repository().get_recent_messages(
            conversation_id,
            limit=limit,
        )

    async def get_conversation_messages(
        self,
        conversation_id: str,
        limit: int = 100,
    ) -> Optional[list[dict]]:
        return await self._get_conversation_repository().get_conversation_messages(
            conversation_id,
            limit=limit,
        )

    async def delete_conversation(self, conversation_id: str) -> bool:
        return await self._get_conversation_repository().delete_conversation(
            conversation_id,
        )

    async def save_voice_turn(
        self,
        conversation_id: str,
        user_message_id: Optional[str] = None,
        assistant_message_id: Optional[str] = None,
        transcript_confidence: Optional[float] = None,
        audio_duration_seconds: Optional[float] = None,
        input_mime_type: Optional[str] = None,
        output_audio_encoding: Optional[str] = None,
        stt_vendor: str = "deepgram",
        tts_vendor: str = "google_tts",
        metadata: Optional[dict] = None,
    ) -> dict:
        return await self._get_conversation_repository().save_voice_turn(
            conversation_id=conversation_id,
            user_message_id=user_message_id,
            assistant_message_id=assistant_message_id,
            transcript_confidence=transcript_confidence,
            audio_duration_seconds=audio_duration_seconds,
            input_mime_type=input_mime_type,
            output_audio_encoding=output_audio_encoding,
            stt_vendor=stt_vendor,
            tts_vendor=tts_vendor,
            metadata=metadata,
        )

    async def save_long_term_memory(
        self,
        memory_type: str,
        content: str,
        source_conversation_id: Optional[str] = None,
        source_message_id: Optional[str] = None,
        importance: int = 3,
        confidence: float = 0.75,
        correction_group: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> dict:
        return await self._get_long_term_memory_repository().save_long_term_memory(
            memory_type=memory_type,
            content=content,
            source_conversation_id=source_conversation_id,
            source_message_id=source_message_id,
            importance=importance,
            confidence=confidence,
            correction_group=correction_group,
            metadata=metadata,
        )

    async def save_long_term_memory_from_message(
        self,
        conversation_id: str,
        message: dict,
    ) -> Optional[dict]:
        return await self._get_long_term_memory_repository().save_long_term_memory_from_message(
            conversation_id,
            message,
        )

    async def get_long_term_memory(
        self,
        query: Optional[str] = None,
        limit: int = 8,
    ) -> list[dict]:
        return await self._get_memory_retrieval_service().get_long_term_memory(
            query=query,
            limit=limit,
        )

    async def get_relevant_memories(self, query: str, limit: int = 8) -> list[dict]:
        return await self._get_memory_retrieval_service().get_relevant_memories(
            query=query,
            limit=limit,
        )

    async def get_structured_memory_context(self, query: str) -> dict:
        return await self._get_memory_retrieval_service().get_structured_memory_context(
            query,
        )

    async def list_long_term_memory(
        self,
        limit: int = 50,
        memory_type: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        return await self._get_long_term_memory_repository().list_long_term_memory(
            limit=limit,
            memory_type=memory_type,
            active=active,
        )

    async def update_long_term_memory(
        self,
        memory_id: str,
        memory_type: Optional[str] = None,
        content: Optional[str] = None,
        importance: Optional[int] = None,
        active: Optional[bool] = None,
        superseded_by: Optional[str] = None,
        confidence: Optional[float] = None,
        correction_group: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        return await self._get_long_term_memory_repository().update_long_term_memory(
            memory_id=memory_id,
            memory_type=memory_type,
            content=content,
            importance=importance,
            active=active,
            superseded_by=superseded_by,
            confidence=confidence,
            correction_group=correction_group,
            metadata=metadata,
        )

    async def deactivate_long_term_memory(self, memory_id: str) -> bool:
        return await self._get_long_term_memory_repository().deactivate_long_term_memory(
            memory_id,
        )

    async def create_memory_correction(self, correction: dict) -> dict:
        return await self._get_memory_candidate_repository().create_memory_correction(
            correction,
        )

    async def list_memory_corrections(
        self,
        limit: int = 50,
        correction_type: Optional[str] = None,
        applied: Optional[bool] = None,
        target_table: Optional[str] = None,
        target_id: Optional[str] = None,
    ) -> list[dict]:
        return await self._get_memory_candidate_repository().list_memory_corrections(
            limit=limit,
            correction_type=correction_type,
            applied=applied,
            target_table=target_table,
            target_id=target_id,
        )

    async def create_memory_candidate(self, candidate: dict) -> dict:
        return await self._get_memory_candidate_repository().create_memory_candidate(
            candidate,
        )

    async def list_memory_candidates(
        self,
        limit: int = 50,
        candidate_type: Optional[str] = None,
        status: Optional[str] = None,
        risk_level: Optional[str] = None,
        source_conversation_id: Optional[str] = None,
    ) -> list[dict]:
        return await self._get_memory_candidate_repository().list_memory_candidates(
            limit=limit,
            candidate_type=candidate_type,
            status=status,
            risk_level=risk_level,
            source_conversation_id=source_conversation_id,
        )

    async def get_memory_candidate(self, candidate_id: str) -> Optional[dict]:
        return await self._get_memory_candidate_repository().get_memory_candidate(
            candidate_id,
        )

    async def update_memory_candidate(
        self,
        candidate_id: str,
        **updates: object,
    ) -> Optional[dict]:
        return await self._get_memory_candidate_repository().update_memory_candidate(
            candidate_id,
            **updates,
        )

    async def create_entity(self, entity: dict) -> dict:
        return await self._get_structured_memory_repository().create_entity(entity)

    async def list_entities(
        self,
        limit: int = 50,
        entity_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
        normalized_name: Optional[str] = None,
    ) -> list[dict]:
        return await self._get_structured_memory_repository().list_entities(
            limit=limit,
            entity_type=entity_type,
            status=status,
            active=active,
            normalized_name=normalized_name,
        )

    async def update_entity(self, entity_id: str, **updates: object) -> Optional[dict]:
        return await self._get_structured_memory_repository().update_entity(
            entity_id,
            **updates,
        )

    async def deactivate_entity(self, entity_id: str) -> Optional[dict]:
        return await self._get_structured_memory_repository().deactivate_entity(
            entity_id,
        )

    async def create_entity_event(self, event: dict) -> dict:
        return await self._get_structured_memory_repository().create_entity_event(
            event,
        )

    async def list_entity_events(
        self,
        limit: int = 50,
        entity_id: Optional[str] = None,
        event_type: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        return await self._get_structured_memory_repository().list_entity_events(
            limit=limit,
            entity_id=entity_id,
            event_type=event_type,
            active=active,
        )

    async def update_entity_event(
        self,
        event_id: str,
        **updates: object,
    ) -> Optional[dict]:
        return await self._get_structured_memory_repository().update_entity_event(
            event_id,
            **updates,
        )

    async def deactivate_entity_event(self, event_id: str) -> Optional[dict]:
        return await self._get_structured_memory_repository().deactivate_entity_event(
            event_id,
        )

    async def create_personal_rule(self, rule: dict) -> dict:
        return await self._get_structured_memory_repository().create_personal_rule(
            rule,
        )

    async def list_personal_rules(
        self,
        limit: int = 50,
        rule_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        return await self._get_structured_memory_repository().list_personal_rules(
            limit=limit,
            rule_type=rule_type,
            status=status,
            active=active,
        )

    async def update_personal_rule(
        self,
        rule_id: str,
        **updates: object,
    ) -> Optional[dict]:
        return await self._get_structured_memory_repository().update_personal_rule(
            rule_id,
            **updates,
        )

    async def deactivate_personal_rule(self, rule_id: str) -> Optional[dict]:
        return await self._get_structured_memory_repository().deactivate_personal_rule(
            rule_id,
        )

    async def create_plan(self, plan: dict) -> dict:
        return await self._get_structured_memory_repository().create_plan(plan)

    async def list_plans(
        self,
        limit: int = 50,
        plan_type: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        return await self._get_structured_memory_repository().list_plans(
            limit=limit,
            plan_type=plan_type,
            status=status,
            active=active,
        )

    async def update_plan(self, plan_id: str, **updates: object) -> Optional[dict]:
        return await self._get_structured_memory_repository().update_plan(
            plan_id,
            **updates,
        )

    async def deactivate_plan(self, plan_id: str) -> Optional[dict]:
        return await self._get_structured_memory_repository().deactivate_plan(plan_id)

    async def create_plan_milestone(self, milestone: dict) -> dict:
        return await self._get_structured_memory_repository().create_plan_milestone(
            milestone,
        )

    async def list_plan_milestones(
        self,
        limit: int = 50,
        plan_id: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        return await self._get_structured_memory_repository().list_plan_milestones(
            limit=limit,
            plan_id=plan_id,
            status=status,
            active=active,
        )

    async def update_plan_milestone(
        self,
        milestone_id: str,
        **updates: object,
    ) -> Optional[dict]:
        return await self._get_structured_memory_repository().update_plan_milestone(
            milestone_id,
            **updates,
        )

    async def deactivate_plan_milestone(self, milestone_id: str) -> Optional[dict]:
        return await self._get_structured_memory_repository().deactivate_plan_milestone(
            milestone_id,
        )

    async def create_commitment(self, commitment: dict) -> dict:
        return await self._get_structured_memory_repository().create_commitment(
            commitment,
        )

    async def list_commitments(
        self,
        limit: int = 50,
        commitment_type: Optional[str] = None,
        plan_id: Optional[str] = None,
        milestone_id: Optional[str] = None,
        entity_id: Optional[str] = None,
        status: Optional[str] = None,
        active: Optional[bool] = None,
    ) -> list[dict]:
        return await self._get_structured_memory_repository().list_commitments(
            limit=limit,
            commitment_type=commitment_type,
            plan_id=plan_id,
            milestone_id=milestone_id,
            entity_id=entity_id,
            status=status,
            active=active,
        )

    async def update_commitment(
        self,
        commitment_id: str,
        **updates: object,
    ) -> Optional[dict]:
        return await self._get_structured_memory_repository().update_commitment(
            commitment_id,
            **updates,
        )

    async def deactivate_commitment(self, commitment_id: str) -> Optional[dict]:
        return await self._get_structured_memory_repository().deactivate_commitment(
            commitment_id,
        )

def is_active_memory(memory: dict) -> bool:
    return memory.get("active") is not False


def memory_accountability_text(memory: dict) -> str:
    return " ".join(
        str(memory.get(field) or "")
        for field in ("content", "memory_type", "relevance_reason")
    )

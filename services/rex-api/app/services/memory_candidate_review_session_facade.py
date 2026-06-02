from typing import Optional

from app.services.memory_candidate_review_session_repository import (
    MemoryCandidateReviewSessionRepository,
)


class MemoryCandidateReviewSessionFacade:
    def _get_memory_candidate_review_session_repository(
        self,
    ) -> MemoryCandidateReviewSessionRepository:
        repository = getattr(
            self,
            "memory_candidate_review_session_repository",
            None,
        )
        if repository is None:
            repository = MemoryCandidateReviewSessionRepository(self)
            self.memory_candidate_review_session_repository = repository
        return repository

    async def create_memory_candidate_review_session(
        self,
        *,
        conversation_id: str,
        candidate_ids: list[str],
        metadata: Optional[dict] = None,
    ) -> dict:
        return await self._get_memory_candidate_review_session_repository().create_review_session(
            conversation_id=conversation_id,
            candidate_ids=candidate_ids,
            metadata=metadata,
        )

    async def get_latest_active_memory_candidate_review_session(
        self,
        *,
        conversation_id: str,
    ) -> Optional[dict]:
        return await self._get_memory_candidate_review_session_repository().get_latest_active_review_session(
            conversation_id=conversation_id,
        )

    async def update_memory_candidate_review_session(
        self,
        session_id: str,
        *,
        status: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        return await self._get_memory_candidate_review_session_repository().update_review_session(
            session_id,
            status=status,
            metadata=metadata,
        )


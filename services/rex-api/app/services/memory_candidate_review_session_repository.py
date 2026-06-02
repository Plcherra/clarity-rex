from datetime import datetime, timezone
from typing import Optional

from app.services.memory_errors import MemoryServiceError


MEMORY_CANDIDATE_REVIEW_SESSION_SELECT = (
    "id,conversation_id,candidate_ids,status,expires_at,metadata,created_at,updated_at"
)
VALID_REVIEW_SESSION_STATUSES = {"active", "completed", "expired"}


class MemoryCandidateReviewSessionRepository:
    def __init__(self, store: object) -> None:
        self.store = store

    async def create_review_session(
        self,
        *,
        conversation_id: str,
        candidate_ids: list[str],
        metadata: Optional[dict] = None,
    ) -> dict:
        if not candidate_ids:
            raise MemoryServiceError("Review session candidate ids are required.", 400)
        return await self.store._create_record(
            self.store.settings.supabase_memory_candidate_review_sessions_table,
            {
                "conversation_id": conversation_id,
                "candidate_ids": candidate_ids,
                "metadata": metadata or {},
            },
            MEMORY_CANDIDATE_REVIEW_SESSION_SELECT,
        )

    async def get_latest_active_review_session(
        self,
        *,
        conversation_id: str,
    ) -> Optional[dict]:
        rows = await self.store._request(
            "GET",
            self.store.settings.supabase_memory_candidate_review_sessions_table,
            query={
                "conversation_id": f"eq.{conversation_id}",
                "status": "eq.active",
                "expires_at": f"gt.{datetime.now(timezone.utc).isoformat()}",
                "select": MEMORY_CANDIDATE_REVIEW_SESSION_SELECT,
                "order": "created_at.desc",
                "limit": "1",
            },
        )
        return rows[0] if rows else None

    async def update_review_session(
        self,
        session_id: str,
        *,
        status: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        if status is not None and status not in VALID_REVIEW_SESSION_STATUSES:
            raise MemoryServiceError("Invalid review session status.", 400)
        updates: dict[str, object] = {}
        if status is not None:
            updates["status"] = status
        if metadata is not None:
            updates["metadata"] = metadata
        return await self.store._update_record(
            self.store.settings.supabase_memory_candidate_review_sessions_table,
            session_id,
            updates=updates,
            select=MEMORY_CANDIDATE_REVIEW_SESSION_SELECT,
            empty_detail="At least one review session field must be provided.",
        )


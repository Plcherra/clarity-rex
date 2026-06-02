from typing import Optional


class MemoryCandidateReviewSessionService:
    """Persists candidate IDs for one pending-memory review operation."""

    def __init__(self, memory_service: object) -> None:
        self.memory_service = memory_service

    async def create_session(
        self,
        *,
        conversation_id: str,
        candidates: list[dict],
    ) -> Optional[dict]:
        candidate_ids = self.candidate_ids(candidates)
        if not candidate_ids:
            return None
        create_session = getattr(
            self.memory_service,
            "create_memory_candidate_review_session",
            None,
        )
        if create_session is None:
            return None
        metadata = {
            "source": "chat_candidate_review",
            "high_risk_candidate_ids": self.high_risk_candidate_ids(candidates),
        }
        try:
            return await create_session(
                conversation_id=conversation_id,
                candidate_ids=candidate_ids,
                metadata=metadata,
            )
        except Exception:
            return None

    async def latest_active_session(
        self,
        *,
        conversation_id: str,
    ) -> Optional[dict]:
        get_session = getattr(
            self.memory_service,
            "get_latest_active_memory_candidate_review_session",
            None,
        )
        if get_session is None:
            return None
        try:
            return await get_session(conversation_id=conversation_id)
        except Exception:
            return None

    async def complete_session(self, session: Optional[dict]) -> None:
        if not session:
            return
        session_id = str(session.get("id") or "")
        if not session_id:
            return
        update_session = getattr(
            self.memory_service,
            "update_memory_candidate_review_session",
            None,
        )
        if update_session is None:
            return
        metadata = dict(session.get("metadata") or {})
        metadata["completed_by"] = "candidate_decision"
        try:
            await update_session(
                session_id,
                status="completed",
                metadata=metadata,
            )
        except Exception:
            return

    def session_candidate_ids(self, session: Optional[dict]) -> list[str]:
        if not session:
            return []
        candidate_ids = session.get("candidate_ids")
        if not isinstance(candidate_ids, list):
            return []
        return [str(candidate_id) for candidate_id in candidate_ids if candidate_id]

    def with_session_payload(
        self,
        response: dict,
        session: Optional[dict],
    ) -> dict:
        if not session:
            return response
        memory_changes = response.get("memory_changes")
        if not isinstance(memory_changes, dict):
            return response
        current = memory_changes.get("review_session")
        if not isinstance(current, dict):
            current = {}
        memory_changes["review_session"] = {
            **current,
            "id": session.get("id"),
            "status": session.get("status"),
            "expires_at": session.get("expires_at"),
            "candidate_ids": self.session_candidate_ids(session),
        }
        return response

    def filter_candidates_to_session(
        self,
        candidates: list[dict],
        session: Optional[dict],
    ) -> list[dict]:
        candidate_ids = set(self.session_candidate_ids(session))
        if not candidate_ids:
            return candidates
        return [
            candidate
            for candidate in candidates
            if str(candidate.get("id") or "") in candidate_ids
        ]

    def candidate_ids(self, candidates: list[dict]) -> list[str]:
        return [
            str(candidate.get("id"))
            for candidate in candidates
            if candidate.get("id") is not None
        ]

    def high_risk_candidate_ids(self, candidates: list[dict]) -> list[str]:
        return [
            str(candidate.get("id"))
            for candidate in candidates
            if candidate.get("id") is not None and candidate.get("risk_level") == "high"
        ]


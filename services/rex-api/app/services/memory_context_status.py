import logging
from dataclasses import dataclass
from typing import Optional


CONTEXT_ERROR_KEY = "_context_error"
CONTEXT_STATUS_KEY = "_context_status"
LOGGER = logging.getLogger("rex.context")


@dataclass(frozen=True)
class ContextFetchError:
    source: str
    message: str

    def as_dict(self) -> dict:
        return {
            CONTEXT_ERROR_KEY: True,
            "source": self.source,
            "message": self.message,
        }


def safe_error_message(exc: Exception) -> str:
    message = str(exc).strip()
    return message or exc.__class__.__name__


class MemoryContextAssembler:
    async def fetch_recent_messages(
        self,
        memory_service,
        conversation_id: str,
        *,
        limit: int = 20,
    ) -> list[dict]:
        try:
            return await memory_service.get_recent_messages(
                conversation_id,
                limit=limit,
            )
        except Exception as exc:
            LOGGER.warning("rex_memory_fetch_failed source=recent_messages")
            return [
                ContextFetchError(
                    source="recent_messages",
                    message=safe_error_message(exc),
                ).as_dict()
            ]

    async def fetch_relevant_memories(
        self,
        memory_service,
        *,
        query: str,
        limit: int,
        source: str = "long_term_memory",
    ) -> list[dict]:
        try:
            return await memory_service.get_relevant_memories(
                query=query,
                limit=limit,
            )
        except Exception as exc:
            LOGGER.warning("rex_memory_fetch_failed source=%s", source)
            return [
                ContextFetchError(
                    source=source,
                    message=safe_error_message(exc),
                ).as_dict()
            ]

    async def fetch_structured_context(
        self,
        memory_service,
        goal_context_service,
        message: str,
        *,
        include_structured_memory: bool = True,
        include_goal_context: bool = True,
    ) -> dict:
        structured_context: dict = {}
        if include_structured_memory:
            get_structured_context = getattr(
                memory_service,
                "get_structured_memory_context",
                None,
            )
            if get_structured_context is not None:
                try:
                    structured_context = await get_structured_context(message)
                except Exception as exc:
                    LOGGER.warning("rex_memory_fetch_failed source=structured_memory")
                    structured_context = {
                        "memory_status": {
                            "state": "degraded",
                            "message": "Structured memory could not be searched.",
                            "attempted_sources": {
                                "structured_memory": True,
                            },
                            "failures": [
                                {
                                    "source": "structured_memory",
                                    "message": safe_error_message(exc),
                                }
                            ],
                        }
                    }

        goal_context = {}
        if include_goal_context:
            goal_context = await goal_context_service.fetch_goal_context(
                memory_service,
                message,
            )
        return goal_context_service.merge_structured_context(
            structured_context,
            goal_context,
        )

    def context_items(
        self,
        items: list[dict],
        failures: list[dict],
        statuses: Optional[list[dict]] = None,
    ) -> list[dict]:
        clean_items = []
        for item in items:
            if item.get(CONTEXT_ERROR_KEY) is True:
                failures.append(
                    {
                        "source": item.get("source") or "memory",
                        "message": item.get("message") or "Memory lookup failed.",
                    }
                )
                continue
            if item.get(CONTEXT_STATUS_KEY) is True:
                if statuses is not None:
                    statuses.append(
                        {
                            key: value
                            for key, value in item.items()
                            if key != CONTEXT_STATUS_KEY
                        }
                    )
                continue
            clean_items.append(item)
        return clean_items

    def with_memory_status(
        self,
        structured_context: dict,
        failures: list[dict],
        *,
        attempted_sources: dict,
        source_statuses: Optional[list[dict]] = None,
    ) -> dict:
        attempted_memory_sources = {
            key: value
            for key, value in attempted_sources.items()
            if key != "recent_messages"
        }
        if not failures and not any(attempted_memory_sources.values()):
            return structured_context

        source_statuses = source_statuses or []
        partial_sources = [
            source_status
            for source_status in source_statuses
            if source_status.get("partial") is True
        ]
        source_failures = [
            failure
            for source_status in partial_sources
            for failure in source_status.get("failures", [])
            if isinstance(failure, dict)
        ]
        all_failures = [*failures, *source_failures]
        status = {
            "state": "degraded" if all_failures or partial_sources else "ready",
            "message": (
                "Some memory sources could not be searched."
                if all_failures or partial_sources
                else "Memory sources searched successfully."
            ),
            "attempted_sources": attempted_sources,
            "failures": all_failures,
            "source_statuses": source_statuses,
        }
        existing = structured_context.get("memory_status")
        if isinstance(existing, dict):
            existing_failures = existing.get("failures")
            if isinstance(existing_failures, list):
                status["failures"] = [*existing_failures, *status["failures"]]
            existing_attempted = existing.get("attempted_sources")
            if isinstance(existing_attempted, dict):
                status["attempted_sources"] = {
                    **existing_attempted,
                    **status["attempted_sources"],
                }
            existing_statuses = existing.get("source_statuses")
            if isinstance(existing_statuses, list):
                status["source_statuses"] = [
                    *existing_statuses,
                    *status["source_statuses"],
                ]
            if status["failures"]:
                status["state"] = "degraded"
                status["message"] = "Some memory sources could not be searched."
        if not structured_context:
            return {"memory_status": status}
        return {**structured_context, "memory_status": status}

    def with_chat_search_results(
        self,
        structured_context: dict,
        chat_search_results: list[dict],
    ) -> dict:
        if not chat_search_results:
            return structured_context
        return {
            **structured_context,
            "chat_search_results": chat_search_results,
        }

    def merge_memories(self, *memory_groups: list[dict]) -> list[dict]:
        merged: list[dict] = []
        seen_ids: set[str] = set()
        for memories in memory_groups:
            for memory in memories:
                memory_id = str(memory.get("id") or "")
                if memory_id and memory_id in seen_ids:
                    continue
                if memory_id:
                    seen_ids.add(memory_id)
                merged.append(memory)
        return merged[:8]

    def prefer_entities_over_flat_memories(
        self,
        memories: list[dict],
        structured_context: dict,
    ) -> list[dict]:
        covered_ids = self.entity_source_memory_ids(structured_context)
        if not covered_ids:
            return memories
        return [
            memory
            for memory in memories
            if str(memory.get("id") or "") not in covered_ids
        ]

    def entity_source_memory_ids(self, structured_context: dict) -> set[str]:
        source_ids: set[str] = set()
        for entity in structured_context.get("entities") or []:
            if not isinstance(entity, dict):
                continue
            source_memory_id = str(entity.get("source_memory_id") or "").strip()
            if source_memory_id:
                source_ids.add(source_memory_id)
            metadata = entity.get("metadata")
            if not isinstance(metadata, dict):
                continue
            for memory_id in metadata.get("source_memory_ids") or []:
                memory_id = str(memory_id or "").strip()
                if memory_id:
                    source_ids.add(memory_id)
        return source_ids

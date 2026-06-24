from __future__ import annotations

from typing import Any

from app.models.plan import (
    PlanCreateRequest,
    PlanMilestoneCreateRequest,
    PlanMilestoneUpdateRequest,
    PlanUpdateRequest,
)
from app.services.memory_service import MemoryServiceError, SupabaseMemoryService
from app.services.plan_entity_linker import PlanEntityLinker
from app.services.plan_errors import PlanServiceError
from app.services.plan_merge_service import (
    PlanMergeService,
    clean_optional,
    clean_required,
    correction_wrong_names,
    is_active_plan,
    is_open_milestone,
)
from app.services.plan_repository import PlanRepository


class PlanService:
    def __init__(self, memory_service: SupabaseMemoryService) -> None:
        self.repository = PlanRepository(memory_service)
        self.entity_linker = PlanEntityLinker(self.repository)
        self.merge_service = PlanMergeService(self.repository)

    async def create_plan(self, request: PlanCreateRequest) -> dict[str, Any]:
        payload = _payload(request)
        payload["title"] = clean_required(payload.get("title"), "title")
        if "description" in payload:
            payload["description"] = clean_optional(payload["description"])
        if "desired_outcome" in payload:
            payload["desired_outcome"] = clean_optional(payload["desired_outcome"])
        payload = await self.entity_linker.normalize_entity_references(
            payload,
            text_fields=("title", "description", "desired_outcome"),
            link_field="primary_entity_id",
        )
        wrong_names = correction_wrong_names(payload)

        try:
            return await self.merge_service.create_or_merge_plan(
                payload,
                wrong_names=wrong_names,
            )
        except MemoryServiceError as error:
            raise PlanServiceError(error.detail, error.status_code) from error

    async def list_plans(
        self,
        *,
        plan_type: str | None = None,
        status: str | None = None,
        active: bool | None = True,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        try:
            return await self.repository.list_plans(
                plan_type=plan_type,
                status=status,
                active=active,
                limit=limit,
            )
        except MemoryServiceError as error:
            raise PlanServiceError(error.detail, error.status_code) from error

    async def update_plan(
        self, plan_id: str, request: PlanUpdateRequest
    ) -> dict[str, Any]:
        payload = _payload(request)
        if "title" in payload:
            payload["title"] = clean_required(payload["title"], "title")
        if "description" in payload:
            payload["description"] = clean_optional(payload["description"])
        if "desired_outcome" in payload:
            payload["desired_outcome"] = clean_optional(payload["desired_outcome"])
        payload = await self.entity_linker.normalize_entity_references(
            payload,
            text_fields=("title", "description", "desired_outcome"),
            link_field="primary_entity_id",
        )

        try:
            updated = await self.repository.update_plan(plan_id, **payload)
        except MemoryServiceError as error:
            raise PlanServiceError(error.detail, error.status_code) from error
        if updated is None:
            raise PlanServiceError("Plan not found.", 404)
        return updated

    async def deactivate_plan(self, plan_id: str) -> dict[str, Any]:
        try:
            updated = await self.repository.deactivate_plan(plan_id)
        except MemoryServiceError as error:
            raise PlanServiceError(error.detail, error.status_code) from error
        if updated is None:
            raise PlanServiceError("Plan not found.", 404)
        return updated

    async def create_milestone(
        self, request: PlanMilestoneCreateRequest
    ) -> dict[str, Any]:
        payload = _payload(request)
        payload["title"] = clean_required(payload.get("title"), "title")
        if "description" in payload:
            payload["description"] = clean_optional(payload["description"])
        payload = await self.entity_linker.normalize_entity_references(
            payload,
            text_fields=("title", "description"),
        )

        try:
            return await self.repository.create_plan_milestone(payload)
        except MemoryServiceError as error:
            raise PlanServiceError(error.detail, error.status_code) from error

    async def list_milestones(
        self,
        *,
        plan_id: str | None = None,
        status: str | None = None,
        active: bool | None = True,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        try:
            return await self.repository.list_plan_milestones(
                plan_id=plan_id,
                status=status,
                active=active,
                limit=limit,
            )
        except MemoryServiceError as error:
            raise PlanServiceError(error.detail, error.status_code) from error

    async def update_milestone(
        self, milestone_id: str, request: PlanMilestoneUpdateRequest
    ) -> dict[str, Any]:
        payload = _payload(request)
        if "title" in payload:
            payload["title"] = clean_required(payload["title"], "title")
        if "description" in payload:
            payload["description"] = clean_optional(payload["description"])
        payload = await self.entity_linker.normalize_entity_references(
            payload,
            text_fields=("title", "description"),
        )

        try:
            updated = await self.repository.update_plan_milestone(
                milestone_id,
                **payload,
            )
        except MemoryServiceError as error:
            raise PlanServiceError(error.detail, error.status_code) from error
        if updated is None:
            raise PlanServiceError("Plan milestone not found.", 404)
        return updated

    async def deactivate_milestone(self, milestone_id: str) -> dict[str, Any]:
        try:
            updated = await self.repository.deactivate_plan_milestone(milestone_id)
        except MemoryServiceError as error:
            raise PlanServiceError(error.detail, error.status_code) from error
        if updated is None:
            raise PlanServiceError("Plan milestone not found.", 404)
        return updated


def _payload(request: Any) -> dict[str, Any]:
    if hasattr(request, "model_dump"):
        return request.model_dump(exclude_none=True)
    return {key: value for key, value in dict(request).items() if value is not None}


_clean_required = clean_required
_clean_optional = clean_optional
_correction_wrong_names = correction_wrong_names

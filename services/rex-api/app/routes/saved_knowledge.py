from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.dependencies import get_memory_service, get_plan_service, get_rule_service
from app.services.commitment_service import CommitmentService
from app.services.memory_service import SupabaseMemoryService
from app.services.plan_service import PlanService
from app.services.rule_service import RuleService
from app.services.saved_knowledge_overview_service import SavedKnowledgeOverviewService


router = APIRouter(prefix="/saved-knowledge", tags=["saved-knowledge"])


def get_saved_knowledge_overview_service(
    memory_service: SupabaseMemoryService = Depends(get_memory_service),
    plan_service: PlanService = Depends(get_plan_service),
    rule_service: RuleService = Depends(get_rule_service),
) -> SavedKnowledgeOverviewService:
    return SavedKnowledgeOverviewService(
        memory_service,
        plan_service=plan_service,
        commitment_service=CommitmentService(memory_service),
        rule_service=rule_service,
    )


@router.get("/overview")
async def get_saved_knowledge_overview(
    active_only: bool = Query(default=True),
    limit: int = Query(default=100, ge=1, le=200),
    service: SavedKnowledgeOverviewService = Depends(
        get_saved_knowledge_overview_service
    ),
) -> dict:
    return await service.get_overview(active_only=active_only, limit=limit)

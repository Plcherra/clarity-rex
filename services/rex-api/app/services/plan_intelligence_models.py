from __future__ import annotations

from typing import Any, Optional

from pydantic import BaseModel, Field

from app.models.memory_discipline import MemoryDisciplineAction


PLAN_INTELLIGENCE_VERSION = 1
PARENT_PLAN_THRESHOLD = 0.28
RELATED_MILESTONE_THRESHOLD = 0.78
TOP_LEVEL_MINIMUM_SPECIFICITY = 0.42
MAX_AUTO_TOP_LEVEL_PLANS = 5
DESCRIPTION_MIN_TOKENS = 8


class PlanIntelligenceDecision(BaseModel):
    action: MemoryDisciplineAction
    payload: dict[str, Any] = Field(default_factory=dict)
    reason: str
    confidence: float = Field(default=0.75, ge=0, le=1)
    parent_plan_id: Optional[str] = None
    target_milestone_id: Optional[str] = None
    requires_confirmation: bool = False
    metadata: dict[str, Any] = Field(default_factory=dict)


class PlanDescriptionQuality(BaseModel):
    passed: bool
    reason: str
    score: float = Field(ge=0, le=1)


class MilestoneClassification(BaseModel):
    kind: str
    reason: str
    confidence: float = Field(default=0.75, ge=0, le=1)
    existing_milestone_id: Optional[str] = None

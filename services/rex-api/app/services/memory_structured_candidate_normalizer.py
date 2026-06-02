import re
from typing import Any, Optional

from app.models.commitment import CommitmentCreateRequest, CommitmentType
from app.models.entity import EntityCreateRequest, EntityEventCreateRequest, EntityType
from app.models.personal_rule import PersonalRuleCreateRequest, RuleType
from app.models.plan import PlanCreateRequest, PlanMilestoneCreateRequest, PlanType
from app.services.memory_extraction_parser import (
    MIN_IMPORTANCE_TO_SAVE,
    looks_noisy,
)


def clean_text(value: Any) -> Optional[str]:
    if value is None:
        return None
    cleaned = " ".join(str(value).split())
    return cleaned or None


def clean_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    cleaned_values = []
    seen = set()
    for item in value:
        cleaned = clean_text(item)
        if not cleaned:
            continue
        key = cleaned.casefold()
        if key in seen:
            continue
        seen.add(key)
        cleaned_values.append(cleaned)
    return cleaned_values


def normalized_text(text: Any) -> str:
    return " ".join(re.findall(r"[a-z0-9]+", str(text).lower()))


def looks_like_vague_entity(display_name: str) -> bool:
    normalized = normalized_text(display_name)
    vague_names = {
        "someone",
        "somebody",
        "a girl",
        "the girl",
        "girl from work",
        "the girl from work",
        "a guy",
        "the guy",
        "guy from work",
        "the guy from work",
        "coworker",
        "a coworker",
        "the coworker",
        "date",
        "my date",
        "dating interest",
        "work",
        "money",
        "budget",
        "thing",
    }
    return normalized in vague_names


def candidate_importance(
    candidate: dict,
    *,
    field_name: str = "importance",
) -> Optional[int]:
    try:
        importance = int(candidate.get(field_name, candidate.get("importance", 0)))
    except (TypeError, ValueError):
        return None
    if importance > 5:
        return None
    return importance


class MemoryStructuredCandidateNormalizer:
    def normalize_entity(
        self,
        candidate: dict,
        *,
        conversation_id: str,
        user_message_id: Optional[str],
    ) -> Optional[dict]:
        importance = candidate_importance(candidate)
        entity_type = str(candidate.get("entity_type", "")).strip().lower()
        display_name = clean_text(candidate.get("display_name"))
        summary = clean_text(candidate.get("summary"))
        relationship = clean_text(candidate.get("relationship"))
        rationale = clean_text(candidate.get("rationale"))

        if importance is None or importance < MIN_IMPORTANCE_TO_SAVE:
            return None
        if entity_type not in EntityType.__args__:
            return None
        if (
            not display_name
            or len(display_name) < 2
            or looks_noisy(display_name)
            or looks_like_vague_entity(display_name)
        ):
            return None

        try:
            payload = EntityCreateRequest(
                entity_type=entity_type,
                display_name=display_name,
                normalized_name=normalized_text(
                    candidate.get("normalized_name") or display_name
                ),
                aliases=clean_list(candidate.get("aliases")),
                relationship=relationship,
                summary=summary,
                source_conversation_id=conversation_id,
                source_message_id=user_message_id,
                importance=importance,
                metadata={"extraction_rationale": rationale or "Useful named context."},
            ).model_dump(exclude_none=True)
        except Exception:
            return None
        return {"payload": payload, "rationale": rationale or "Useful named context."}

    def normalize_entity_event(
        self,
        candidate: dict,
        *,
        conversation_id: str,
        user_message_id: Optional[str],
    ) -> Optional[dict]:
        importance = candidate_importance(candidate)
        entity_id = clean_text(candidate.get("entity_id"))
        event_type = str(candidate.get("event_type", "note")).strip().lower() or "note"
        title = clean_text(candidate.get("title"))
        content = clean_text(candidate.get("content"))
        rationale = clean_text(candidate.get("rationale"))

        if importance is None or importance < MIN_IMPORTANCE_TO_SAVE:
            return None
        if not entity_id:
            return None
        if not content or looks_noisy(content):
            return None

        try:
            payload = EntityEventCreateRequest(
                entity_id=entity_id,
                event_type=event_type,
                title=title,
                content=content,
                source_conversation_id=conversation_id,
                source_message_id=user_message_id,
                importance=importance,
                metadata={
                    "entity_name": clean_text(candidate.get("entity_name")),
                    "extraction_rationale": rationale or "Useful entity event.",
                },
            ).model_dump(exclude_none=True)
        except Exception:
            return None
        return {"payload": payload, "rationale": rationale or "Useful entity event."}

    def normalize_rule(
        self,
        candidate: dict,
        *,
        conversation_id: str,
        user_message_id: Optional[str],
    ) -> Optional[dict]:
        priority = candidate_importance(candidate, field_name="priority")
        rule_type = str(candidate.get("rule_type", "")).strip().lower()
        title = clean_text(candidate.get("title"))
        rule_text = clean_text(candidate.get("rule_text"))
        rationale = clean_text(candidate.get("rationale"))

        if priority is None or priority < MIN_IMPORTANCE_TO_SAVE:
            return None
        if rule_type not in RuleType.__args__:
            return None
        if not title or not rule_text or looks_noisy(rule_text):
            return None

        try:
            payload = PersonalRuleCreateRequest(
                rule_type=rule_type,
                title=title,
                rule_text=rule_text,
                trigger_keywords=clean_list(candidate.get("trigger_keywords")),
                source_conversation_id=conversation_id,
                source_message_id=user_message_id,
                priority=priority,
                metadata={"extraction_rationale": rationale or "Useful personal rule."},
            ).model_dump(exclude_none=True)
        except Exception:
            return None
        return {"payload": payload, "rationale": rationale or "Useful personal rule."}

    def normalize_plan(
        self,
        candidate: dict,
        *,
        conversation_id: str,
        user_message_id: Optional[str],
    ) -> Optional[dict]:
        priority = candidate_importance(candidate, field_name="priority")
        plan_type = str(candidate.get("plan_type", "")).strip().lower()
        title = clean_text(candidate.get("title"))
        description = clean_text(candidate.get("description"))
        desired_outcome = clean_text(candidate.get("desired_outcome"))
        primary_entity_id = clean_text(
            candidate.get("primary_entity_id") or candidate.get("entity_id")
        )
        rationale = clean_text(candidate.get("rationale"))

        if priority is None or priority < MIN_IMPORTANCE_TO_SAVE:
            return None
        if plan_type not in PlanType.__args__:
            return None
        if not title or looks_noisy(title):
            return None

        try:
            payload = PlanCreateRequest(
                plan_type=plan_type,
                title=title,
                description=description,
                desired_outcome=desired_outcome,
                primary_entity_id=primary_entity_id,
                source_conversation_id=conversation_id,
                source_message_id=user_message_id,
                priority=priority,
                metadata={"extraction_rationale": rationale or "Useful plan context."},
            ).model_dump(exclude_none=True)
        except Exception:
            return None
        return {"payload": payload, "rationale": rationale or "Useful plan context."}

    def normalize_plan_milestone(
        self,
        candidate: dict,
        *,
        conversation_id: str,
        user_message_id: Optional[str],
    ) -> Optional[dict]:
        priority = candidate_importance(candidate, field_name="priority")
        plan_id = clean_text(candidate.get("plan_id"))
        title = clean_text(candidate.get("title"))
        description = clean_text(candidate.get("description"))
        milestone_type = (
            str(candidate.get("milestone_type", "checkpoint")).strip().lower()
            or "checkpoint"
        )
        target_date = clean_text(candidate.get("target_date"))
        rationale = clean_text(candidate.get("rationale"))

        if priority is None or priority < MIN_IMPORTANCE_TO_SAVE:
            return None
        if not plan_id:
            return None
        if not title or looks_noisy(title):
            return None

        try:
            payload = PlanMilestoneCreateRequest(
                plan_id=plan_id,
                title=title,
                description=description,
                milestone_type=milestone_type,
                target_date=target_date,
                source_conversation_id=conversation_id,
                source_message_id=user_message_id,
                priority=priority,
                metadata={
                    "plan_title": clean_text(candidate.get("plan_title")),
                    "extraction_rationale": rationale or "Useful plan milestone.",
                },
            ).model_dump(exclude_none=True)
        except Exception:
            return None
        return {"payload": payload, "rationale": rationale or "Useful plan milestone."}

    def normalize_commitment(
        self,
        candidate: dict,
        *,
        conversation_id: str,
        user_message_id: Optional[str],
    ) -> Optional[dict]:
        priority = candidate_importance(candidate, field_name="priority")
        commitment_type = str(candidate.get("commitment_type", "")).strip().lower()
        title = clean_text(candidate.get("title"))
        commitment_text = clean_text(candidate.get("commitment_text"))
        due_at = clean_text(candidate.get("due_at"))
        rationale = clean_text(candidate.get("rationale"))
        entity_id = clean_text(candidate.get("entity_id"))
        plan_id = clean_text(candidate.get("plan_id"))
        milestone_id = clean_text(candidate.get("milestone_id"))

        if priority is None or priority < MIN_IMPORTANCE_TO_SAVE:
            return None
        if commitment_type not in CommitmentType.__args__:
            return None
        if not title or not commitment_text or looks_noisy(commitment_text):
            return None

        try:
            payload = CommitmentCreateRequest(
                commitment_type=commitment_type,
                title=title,
                commitment_text=commitment_text,
                entity_id=entity_id,
                plan_id=plan_id,
                milestone_id=milestone_id,
                source_conversation_id=conversation_id,
                source_message_id=user_message_id,
                priority=priority,
                due_at=due_at,
                metadata={"extraction_rationale": rationale or "Useful commitment."},
            ).model_dump(exclude_none=True)
        except Exception:
            return None
        return {"payload": payload, "rationale": rationale or "Useful commitment."}

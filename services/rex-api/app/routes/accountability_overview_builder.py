import re

from app.models.accountability import (
    AccountabilityOverviewResponse,
    AccountabilitySignalResponse,
)
from app.routes.accountability_signal_filters import filter_signals
from app.services.accountability_snapshot import (
    active_plans_for,
    completed_milestones_for,
    open_commitments_for,
    open_milestones_for,
)


def build_accountability_overview(
    *,
    message: str,
    context: dict,
    signals: list[AccountabilitySignalResponse],
    limit: int,
) -> AccountabilityOverviewResponse:
    active_signals = filter_signals(
        signals,
        signal_type=None,
        severity=None,
        status="active",
        source_type=None,
        limit=limit,
    )
    rule_risks = [
        signal for signal in active_signals if signal.signal_type == "rule_violation"
    ]
    plan_risks = [
        signal
        for signal in active_signals
        if signal.signal_type in {"plan_drift", "upcoming_deadline"}
    ]
    recent_patterns = [
        signal for signal in active_signals if signal.signal_type == "repeated_pattern"
    ]
    open_commitments = open_commitments_for(context["commitments"])
    open_milestones = open_milestones_for(context["plan_milestones"])
    completed_milestones = completed_milestones_for(context["plan_milestones"])
    active_plans = active_plans_for(context["plans"])
    plan_hierarchy = plan_hierarchy_for(
        plans=active_plans,
        milestones=open_milestones,
        completed_milestones=completed_milestones,
        commitments=open_commitments,
    )
    duplicate_warnings = duplicate_warnings_for(
        plans=active_plans,
        rules=context["personal_rules"],
        milestones=open_milestones,
        commitments=open_commitments,
        entities=context["entities"],
    )
    duplicate_warnings.extend(
        cleanup_warnings_for(
            plan_hierarchy=plan_hierarchy,
            open_milestones=open_milestones,
        )
    )

    return AccountabilityOverviewResponse(
        signals=active_signals,
        rule_risks=rule_risks,
        plan_risks=plan_risks,
        recent_patterns=recent_patterns,
        active_rules=context["personal_rules"],
        open_commitments=open_commitments,
        active_plans=active_plans,
        open_milestones=open_milestones,
        completed_milestones=completed_milestones,
        plan_hierarchy=plan_hierarchy,
        duplicate_warnings=duplicate_warnings,
        metadata={
            "message": message,
            "signal_count": len(active_signals),
            "active_rule_count": len(context["personal_rules"]),
            "open_commitment_count": len(open_commitments),
            "active_plan_count": len(active_plans),
            "open_milestone_count": len(open_milestones),
            "completed_milestone_count": len(completed_milestones),
            "open_task_count": len(open_commitments),
            "duplicate_warning_count": len(duplicate_warnings),
            "loader_diagnostics": context.get("loader_diagnostics", []),
        },
    )


def plan_hierarchy_for(
    *,
    plans: list[dict],
    milestones: list[dict],
    completed_milestones: list[dict],
    commitments: list[dict],
) -> list[dict]:
    milestones_by_plan: dict[str, list[dict]] = {}
    completed_by_plan: dict[str, list[dict]] = {}
    commitments_by_plan: dict[str, list[dict]] = {}
    commitments_by_milestone: dict[str, list[dict]] = {}

    for milestone in milestones:
        plan_id = str(milestone.get("plan_id") or "")
        if plan_id:
            milestones_by_plan.setdefault(plan_id, []).append(milestone)

    for milestone in completed_milestones:
        plan_id = str(milestone.get("plan_id") or "")
        if plan_id:
            completed_by_plan.setdefault(plan_id, []).append(milestone)

    for commitment in commitments:
        milestone_id = str(commitment.get("milestone_id") or "")
        plan_id = str(commitment.get("plan_id") or "")
        if milestone_id:
            commitments_by_milestone.setdefault(milestone_id, []).append(commitment)
        elif plan_id:
            commitments_by_plan.setdefault(plan_id, []).append(commitment)

    return [
        _plan_hierarchy_item(
            plan=plan,
            milestones_by_plan=milestones_by_plan,
            completed_by_plan=completed_by_plan,
            commitments_by_plan=commitments_by_plan,
            commitments_by_milestone=commitments_by_milestone,
        )
        for plan in plans
    ]


def duplicate_warnings_for(
    *,
    plans: list[dict],
    rules: list[dict],
    milestones: list[dict],
    commitments: list[dict],
    entities: list[dict],
) -> list[dict]:
    warnings = []
    warnings.extend(_duplicate_warning_group(plans, "plan", "title"))
    warnings.extend(_duplicate_warning_group(rules, "rule", "title"))
    warnings.extend(_duplicate_warning_group(milestones, "milestone", "title"))
    warnings.extend(_duplicate_warning_group(commitments, "commitment", "title"))
    warnings.extend(entity_conflict_warnings_for(entities))
    return warnings


def cleanup_warnings_for(
    *,
    plan_hierarchy: list[dict],
    open_milestones: list[dict],
) -> list[dict]:
    warnings = []
    if len(open_milestones) >= 20:
        warnings.append(
            {
                "record_type": "milestone",
                "title": "Too many open milestones",
                "record_ids": [
                    str(milestone.get("id"))
                    for milestone in open_milestones[:20]
                    if milestone.get("id")
                ],
                "reason": "open_milestone_count_exceeds_cleanup_threshold",
            }
        )

    for item in plan_hierarchy:
        open_count = int(item.get("counts", {}).get("open_milestones") or 0)
        if open_count < 8:
            continue
        plan = item.get("plan") or {}
        warnings.append(
            {
                "record_type": "plan",
                "title": f"{plan.get('title') or 'Plan'} needs milestone cleanup",
                "record_ids": [str(plan.get("id"))] if plan.get("id") else [],
                "reason": "plan_open_milestone_count_exceeds_cleanup_threshold",
            }
        )
    return warnings


def entity_conflict_warnings_for(entities: list[dict]) -> list[dict]:
    warnings = []
    for entity in entities:
        if entity.get("active") is False:
            continue
        normalized = _entity_conflict_text(entity)
        has_job_conflict = _has_affirmative_fired_fact(normalized) and any(
            term in normalized for term in ("quit", "resigned", "left")
        )
        has_route_conflict = (
            "primary" in normalized
            and any(term in normalized for term in ("backup", "fallback"))
        )
        if has_job_conflict or has_route_conflict:
            warnings.append(_entity_warning(entity))
    return warnings


def _plan_hierarchy_item(
    *,
    plan: dict,
    milestones_by_plan: dict[str, list[dict]],
    completed_by_plan: dict[str, list[dict]],
    commitments_by_plan: dict[str, list[dict]],
    commitments_by_milestone: dict[str, list[dict]],
) -> dict:
    plan_id = str(plan.get("id") or "")
    plan_milestones = [
        {
            **milestone,
            "open_commitments": commitments_by_milestone.get(
                str(milestone.get("id") or ""),
                [],
            ),
        }
        for milestone in milestones_by_plan.get(plan_id, [])
    ]
    return {
        "plan": plan,
        "open_milestones": plan_milestones,
        "completed_milestones": completed_by_plan.get(plan_id, []),
        "open_commitments": commitments_by_plan.get(plan_id, []),
        "counts": {
            "open_milestones": len(plan_milestones),
            "completed_milestones": len(completed_by_plan.get(plan_id, [])),
            "open_commitments": len(commitments_by_plan.get(plan_id, []))
            + sum(
                len(item.get("open_commitments") or [])
                for item in plan_milestones
            ),
        },
    }


def _duplicate_warning_group(
    records: list[dict],
    record_type: str,
    title_field: str,
) -> list[dict]:
    text_fields_by_type = {
        "plan": ("title", "description", "desired_outcome"),
        "rule": ("title", "rule_text"),
        "milestone": ("title", "description"),
        "commitment": ("title", "commitment_text"),
    }
    groups: dict[str, list[dict]] = {}
    for record in records:
        if record.get("active") is False:
            continue
        key = _duplicate_key(record, text_fields_by_type[record_type])
        if key:
            groups.setdefault(key, []).append(record)

    return [
        {
            "record_type": record_type,
            "title": str(group[0].get(title_field) or record_type),
            "record_ids": [
                str(record.get("id")) for record in group if record.get("id")
            ],
            "reason": "multiple_active_records_share_core_wording",
        }
        for group in groups.values()
        if len(group) >= 2
    ]


def _duplicate_key(record: dict, fields: tuple[str, ...]) -> str:
    parts = [str(record.get(field) or "") for field in fields]
    text = " ".join(parts).casefold()
    semantic_key = _semantic_duplicate_key(text)
    if semantic_key:
        return semantic_key
    tokens = [
        token
        for token in re.findall(r"[a-z0-9$]+", text)
        if len(token) > 2
        and token
        not in {
            "active",
            "and",
            "for",
            "from",
            "goal",
            "plan",
            "the",
            "this",
            "with",
        }
    ]
    return " ".join(tokens[:8])


def _semantic_duplicate_key(text: str) -> str:
    tokens = set(re.findall(r"[a-z0-9$]+", text.casefold()))
    if tokens & _RELOCATION_TERMS:
        return "semantic:life_freedom_relocation"
    if tokens & _APP_ROADMAP_TERMS:
        return "semantic:app_development_roadmap"
    if tokens & {"date", "dating", "dinner", "melissa", "restaurant"}:
        return "semantic:dating_melissa"
    if tokens & {"doordash", "uber", "delivery"}:
        return "semantic:avoid_delivery_transport"
    if tokens & {"paycheck", "saving", "savings", "transfer"}:
        return "semantic:paycheck_savings"
    return ""


def _entity_conflict_text(entity: dict) -> str:
    text = " ".join(
        str(entity.get(field) or "")
        for field in ("display_name", "name", "summary", "relationship")
    )
    aliases = entity.get("aliases")
    if isinstance(aliases, list):
        text = f"{text} {' '.join(str(alias) for alias in aliases)}"
    return text.casefold()


def _entity_warning(entity: dict) -> dict:
    title = str(
        entity.get("display_name") or entity.get("name") or "Entity fact conflict"
    )
    return {
        "record_type": "entity",
        "title": title,
        "record_ids": [str(entity.get("id"))] if entity.get("id") else [],
        "reason": "possible_conflicting_entity_facts",
    }


def _has_affirmative_fired_fact(normalized_text: str) -> bool:
    negated_phrases = (
        "not fired",
        "never fired",
        "was not fired",
        "wasn't fired",
        "wasn t fired",
    )
    if any(phrase in normalized_text for phrase in negated_phrases):
        return False
    return any(
        phrase in normalized_text
        for phrase in (
            "got fired",
            "was fired",
            "fired at",
            "fired from",
            "got laid off",
        )
    )


_RELOCATION_TERMS = {
    "abroad",
    "citizenship",
    "digital",
    "estonia",
    "europe",
    "greece",
    "immigration",
    "italian",
    "italy",
    "nomad",
    "portugal",
    "relocate",
    "relocating",
    "relocation",
    "residency",
    "usa",
    "visa",
}

_APP_ROADMAP_TERMS = {
    "app",
    "apps",
    "clarity",
    "development",
    "echodesk",
    "flowforce",
    "launch",
    "mvp",
    "rex",
    "ship",
}

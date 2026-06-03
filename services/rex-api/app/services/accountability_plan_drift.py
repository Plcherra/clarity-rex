from datetime import date, datetime
from typing import Optional

from app.models.accountability import AccountabilitySignal
from app.services.accountability_shared import (
    PLAN_STALL_DAYS,
    PROGRESS_TERMS,
    UPCOMING_MILESTONE_DAYS,
    bounded_int,
    contains_term,
    meaningful_terms,
    milestone_source_ref,
    normalize_text,
    parse_date,
    parse_datetime,
    plan_source_ref,
    tokens,
)
from app.services.plan_service import is_active_plan, is_open_milestone


def detect_plan_signals(
    *,
    message: str,
    plans: list[dict],
    plan_milestones: list[dict],
    current_time: datetime,
) -> list[AccountabilitySignal]:
    normalized_message = normalize_text(message)
    message_tokens = set(tokens(normalized_message))
    active_plans = {
        str(plan.get("id")): plan
        for plan in plans
        if plan.get("id") and is_active_plan(plan)
    }
    signals: list[AccountabilitySignal] = []

    for plan in active_plans.values():
        matched_terms = matched_plan_terms(normalized_message, plan)
        if matched_terms and message_tokens & PROGRESS_TERMS:
            signals.append(plan_progress_signal(plan=plan, matched_terms=matched_terms))

        target_date = parse_date(plan.get("target_date"))
        if target_date is not None and target_date < current_time.date():
            signals.append(
                plan_target_drift_signal(
                    plan=plan,
                    target_date=target_date,
                    current_time=current_time,
                )
            )
            continue

        last_reviewed_at = parse_datetime(plan.get("last_reviewed_at"))
        if is_plan_stalled(plan, last_reviewed_at, current_time):
            signals.append(
                stalled_plan_signal(plan=plan, last_reviewed_at=last_reviewed_at)
            )

    for milestone in plan_milestones:
        if not is_open_milestone(milestone):
            continue
        plan = active_plans.get(str(milestone.get("plan_id")))
        if plan is None:
            continue

        matched_terms = matched_milestone_terms(normalized_message, milestone, plan)
        if matched_terms and message_tokens & PROGRESS_TERMS:
            signals.append(
                milestone_progress_signal(
                    milestone=milestone,
                    plan=plan,
                    matched_terms=matched_terms,
                )
            )
            continue

        target_date = parse_date(milestone.get("target_date"))
        if target_date is None:
            continue
        if target_date < current_time.date():
            signals.append(
                overdue_milestone_signal(
                    milestone=milestone,
                    plan=plan,
                    target_date=target_date,
                    current_time=current_time,
                )
            )
        elif (target_date - current_time.date()).days <= UPCOMING_MILESTONE_DAYS:
            signals.append(
                upcoming_milestone_signal(
                    milestone=milestone,
                    plan=plan,
                    target_date=target_date,
                    current_time=current_time,
                )
            )

    return signals


def matched_plan_terms(normalized_message: str, plan: dict) -> list[str]:
    terms = plan_terms(plan)
    return sorted(term for term in terms if contains_term(normalized_message, term))


def matched_milestone_terms(
    normalized_message: str,
    milestone: dict,
    plan: dict,
) -> list[str]:
    terms = plan_terms(plan) | milestone_terms(milestone)
    return sorted(term for term in terms if contains_term(normalized_message, term))


def plan_terms(plan: dict) -> set[str]:
    text = normalize_text(
        " ".join(
            str(plan.get(field) or "")
            for field in ("title", "description", "desired_outcome", "plan_type")
        )
    )
    return meaningful_terms(text)


def milestone_terms(milestone: dict) -> set[str]:
    text = normalize_text(
        " ".join(
            str(milestone.get(field) or "")
            for field in ("title", "description", "milestone_type")
        )
    )
    return meaningful_terms(text)


def is_plan_stalled(
    plan: dict,
    last_reviewed_at: Optional[datetime],
    current_time: datetime,
) -> bool:
    priority = bounded_int(plan.get("priority"), default=3, minimum=1, maximum=5)
    if priority < 4:
        return False
    if last_reviewed_at is None:
        created_at = parse_datetime(plan.get("created_at"))
        if created_at is None:
            return True
        last_reviewed_at = created_at
    return (current_time - last_reviewed_at).days >= PLAN_STALL_DAYS


def plan_progress_signal(*, plan: dict, matched_terms: list[str]) -> AccountabilitySignal:
    title = str(plan.get("title") or "Plan").strip()

    return AccountabilitySignal(
        signal_type="positive_follow_through",
        title=f"Plan progress reported: {title}",
        summary=f"The user appears to report progress on: {title}.",
        reason=(
            "The current message uses progress language and matched plan "
            f"terms: {', '.join(matched_terms[:4])}."
        ),
        severity="info",
        confidence=0.74,
        source_refs=[plan_source_ref(plan)],
        suggested_prompt=f"That sounds like progress on {title}.",
        recommended_action=(
            "Acknowledge the progress and ask whether the plan status or "
            "next milestone should be updated."
        ),
        metadata={
            "subtype": "plan_progress",
            "matched_terms": matched_terms,
            "plan_status": plan.get("status"),
        },
    )


def milestone_progress_signal(
    *,
    milestone: dict,
    plan: dict,
    matched_terms: list[str],
) -> AccountabilitySignal:
    title = str(milestone.get("title") or "Milestone").strip()

    return AccountabilitySignal(
        signal_type="positive_follow_through",
        title=f"Milestone progress reported: {title}",
        summary=f"The user appears to report progress on milestone: {title}.",
        reason=(
            "The current message uses progress language and matched milestone "
            f"terms: {', '.join(matched_terms[:4])}."
        ),
        severity="info",
        confidence=0.78,
        source_refs=[milestone_source_ref(milestone), plan_source_ref(plan)],
        suggested_prompt=f"That sounds like progress on {title}.",
        recommended_action=(
            "Acknowledge the update and ask whether the milestone should be "
            "marked in progress or complete."
        ),
        metadata={
            "subtype": "milestone_progress",
            "matched_terms": matched_terms,
            "milestone_status": milestone.get("status"),
            "plan_id": plan.get("id"),
        },
    )


def plan_target_drift_signal(
    *,
    plan: dict,
    target_date: date,
    current_time: datetime,
) -> AccountabilitySignal:
    title = str(plan.get("title") or "Plan").strip()
    days_overdue = (current_time.date() - target_date).days
    priority = bounded_int(plan.get("priority"), default=3, minimum=1, maximum=5)

    return AccountabilitySignal(
        signal_type="plan_drift",
        title=f"Plan target missed: {title}",
        summary=f"The active plan target date has passed: {title}.",
        reason=f"Target date was {target_date.isoformat()} and plan is still active.",
        severity="high" if priority >= 5 or days_overdue >= 14 else "medium",
        confidence=0.86,
        source_refs=[plan_source_ref(plan)],
        suggested_prompt=f"The target for {title} has passed.",
        recommended_action=(
            "Ask if the plan should be rescheduled, completed, or abandoned."
        ),
        metadata={
            "subtype": "plan_target_missed",
            "target_date": target_date.isoformat(),
            "days_overdue": days_overdue,
            "plan_priority": priority,
        },
    )


def stalled_plan_signal(
    *,
    plan: dict,
    last_reviewed_at: Optional[datetime],
) -> AccountabilitySignal:
    title = str(plan.get("title") or "Plan").strip()
    priority = bounded_int(plan.get("priority"), default=3, minimum=1, maximum=5)

    return AccountabilitySignal(
        signal_type="plan_drift",
        title=f"Plan needs review: {title}",
        summary=f"High-priority plan has no recent review: {title}.",
        reason="The active plan is high priority and has not been reviewed recently.",
        severity="low" if priority < 5 else "medium",
        confidence=0.68,
        source_refs=[plan_source_ref(plan)],
        suggested_prompt=f"Quick review on {title}: what changed since last check-in?",
        recommended_action="Ask for current status, blockers, and the next concrete step.",
        metadata={
            "subtype": "stalled_plan",
            "plan_priority": priority,
            "last_reviewed_at": last_reviewed_at.isoformat()
            if last_reviewed_at
            else None,
        },
    )


def overdue_milestone_signal(
    *,
    milestone: dict,
    plan: dict,
    target_date: date,
    current_time: datetime,
) -> AccountabilitySignal:
    title = str(milestone.get("title") or "Milestone").strip()
    days_overdue = (current_time.date() - target_date).days
    priority = bounded_int(
        milestone.get("priority"),
        default=bounded_int(plan.get("priority"), default=3, minimum=1, maximum=5),
        minimum=1,
        maximum=5,
    )

    return AccountabilitySignal(
        signal_type="plan_drift",
        title=f"Milestone overdue: {title}",
        summary=f"Plan milestone is overdue: {title}.",
        reason=(
            f"Milestone target date was {target_date.isoformat()} and "
            "it is still open."
        ),
        severity="high" if priority >= 5 or days_overdue >= 7 else "medium",
        confidence=0.88,
        source_refs=[milestone_source_ref(milestone), plan_source_ref(plan)],
        suggested_prompt=f"The milestone {title} is overdue.",
        recommended_action=(
            "Ask whether it is complete. If not, help reset a realistic next step."
        ),
        metadata={
            "subtype": "overdue_milestone",
            "target_date": target_date.isoformat(),
            "days_overdue": days_overdue,
            "milestone_status": milestone.get("status"),
            "plan_id": plan.get("id"),
        },
    )


def upcoming_milestone_signal(
    *,
    milestone: dict,
    plan: dict,
    target_date: date,
    current_time: datetime,
) -> AccountabilitySignal:
    title = str(milestone.get("title") or "Milestone").strip()
    days_until_due = (target_date - current_time.date()).days

    return AccountabilitySignal(
        signal_type="upcoming_deadline",
        title=f"Milestone coming up: {title}",
        summary=f"Plan milestone is coming up: {title}.",
        reason=f"Milestone target date is {target_date.isoformat()}.",
        severity="medium" if days_until_due <= 2 else "low",
        confidence=0.82,
        source_refs=[milestone_source_ref(milestone), plan_source_ref(plan)],
        suggested_prompt=f"{title} is due soon.",
        recommended_action=(
            "Connect the current message to the milestone and ask for the next step."
        ),
        metadata={
            "subtype": "upcoming_milestone",
            "target_date": target_date.isoformat(),
            "days_until_due": days_until_due,
            "milestone_status": milestone.get("status"),
            "plan_id": plan.get("id"),
        },
    )

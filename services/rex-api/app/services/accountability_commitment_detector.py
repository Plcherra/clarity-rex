from datetime import datetime
from typing import Optional

from app.models.accountability import AccountabilitySignal
from app.services.accountability_shared import (
    COMPLETION_TERMS,
    FOLLOW_UP_AGE_DAYS,
    bounded_int,
    commitment_source_ref,
    contains_term,
    normalize_text,
    parse_datetime,
    tokens,
)
from app.services.commitment_service import is_open_commitment


def detect_commitment_signals(
    *,
    message: str,
    commitments: list[dict],
    current_time: datetime,
) -> list[AccountabilitySignal]:
    normalized_message = normalize_text(message)
    message_tokens = set(tokens(normalized_message))
    signals = []

    for commitment in commitments:
        if not is_open_commitment(commitment):
            continue

        matched_terms = matched_commitment_terms(normalized_message, commitment)
        if matched_terms and message_tokens & COMPLETION_TERMS:
            signals.append(
                positive_follow_through_signal(
                    commitment=commitment,
                    matched_terms=matched_terms,
                )
            )
            continue

        due_at = parse_datetime(commitment.get("due_at"))
        if due_at is not None:
            if due_at < current_time:
                signals.append(
                    missed_commitment_signal(
                        commitment=commitment,
                        due_at=due_at,
                        current_time=current_time,
                    )
                )
            elif due_at.astimezone(current_time.tzinfo).date() == current_time.date():
                signals.append(
                    due_today_commitment_signal(
                        commitment=commitment,
                        due_at=due_at,
                        current_time=current_time,
                    )
                )
            continue

        last_checked_at = parse_datetime(commitment.get("last_checked_at"))
        if needs_commitment_follow_up(commitment, last_checked_at, current_time):
            signals.append(
                commitment_follow_up_signal(
                    commitment=commitment,
                    last_checked_at=last_checked_at,
                )
            )

    return signals


def matched_commitment_terms(normalized_message: str, commitment: dict) -> list[str]:
    terms_ = commitment_terms(commitment)
    return sorted(term for term in terms_ if contains_term(normalized_message, term))


def commitment_terms(commitment: dict) -> set[str]:
    text = normalize_text(
        " ".join(
            str(commitment.get(field) or "")
            for field in ("title", "commitment_text", "commitment_type")
        )
    )
    stop_terms = {
        "about",
        "again",
        "commitment",
        "need",
        "open",
        "task",
        "that",
        "the",
        "this",
        "will",
        "with",
    }
    return {token for token in tokens(text) if len(token) >= 4 and token not in stop_terms}


def needs_commitment_follow_up(
    commitment: dict,
    last_checked_at: Optional[datetime],
    current_time: datetime,
) -> bool:
    priority = bounded_int(commitment.get("priority"), default=3, minimum=1, maximum=5)
    if priority < 4:
        return False
    if last_checked_at is None:
        return True
    return (current_time - last_checked_at).days >= FOLLOW_UP_AGE_DAYS


def missed_commitment_signal(
    *,
    commitment: dict,
    due_at: datetime,
    current_time: datetime,
) -> AccountabilitySignal:
    priority = bounded_int(commitment.get("priority"), default=3, minimum=1, maximum=5)
    overdue_hours = max((current_time - due_at).total_seconds() / 3600, 0)
    severity = "high" if priority >= 5 or overdue_hours >= 24 else "medium"
    title = str(commitment.get("title") or "Commitment").strip()
    text = str(commitment.get("commitment_text") or "").strip()

    return AccountabilitySignal(
        signal_type="missed_commitment",
        title=f"Missed commitment: {title}",
        summary=f"The commitment is overdue: {title}.",
        reason=f"Due at {due_at.isoformat()} and still marked open.",
        severity=severity,
        confidence=0.9,
        source_refs=[commitment_source_ref(commitment)],
        suggested_prompt=f"You committed to this: {text or title}. It is overdue now.",
        recommended_action=(
            "Ask whether it was completed. If not, get a concrete recovery step."
        ),
        metadata={
            "commitment_status": commitment.get("status"),
            "commitment_priority": priority,
            "due_at": due_at.isoformat(),
            "overdue_hours": round(overdue_hours, 2),
        },
    )


def due_today_commitment_signal(
    *,
    commitment: dict,
    due_at: datetime,
    current_time: datetime,
) -> AccountabilitySignal:
    priority = bounded_int(commitment.get("priority"), default=3, minimum=1, maximum=5)
    title = str(commitment.get("title") or "Commitment").strip()
    text = str(commitment.get("commitment_text") or "").strip()
    hours_until_due = max((due_at - current_time).total_seconds() / 3600, 0)

    return AccountabilitySignal(
        signal_type="upcoming_deadline",
        title=f"Commitment due today: {title}",
        summary=f"The commitment is due today: {title}.",
        reason=f"Due at {due_at.isoformat()} and still marked open.",
        severity="medium" if priority >= 4 else "low",
        confidence=0.86,
        source_refs=[commitment_source_ref(commitment)],
        suggested_prompt=f"This is due today: {text or title}.",
        recommended_action="Ask for the next concrete action before the day slips.",
        metadata={
            "subtype": "commitment_due_today",
            "commitment_status": commitment.get("status"),
            "commitment_priority": priority,
            "due_at": due_at.isoformat(),
            "hours_until_due": round(hours_until_due, 2),
        },
    )


def positive_follow_through_signal(
    *,
    commitment: dict,
    matched_terms: list[str],
) -> AccountabilitySignal:
    title = str(commitment.get("title") or "Commitment").strip()
    text = str(commitment.get("commitment_text") or "").strip()

    return AccountabilitySignal(
        signal_type="positive_follow_through",
        title=f"Follow-through reported: {title}",
        summary=f"The user appears to report completing: {title}.",
        reason=(
            "The current message uses completion language and matched "
            f"commitment terms: {', '.join(matched_terms[:4])}."
        ),
        severity="info",
        confidence=0.78,
        source_refs=[commitment_source_ref(commitment)],
        suggested_prompt=f"Looks like you followed through on: {text or title}.",
        recommended_action=(
            "Acknowledge the follow-through and ask if this should be marked complete."
        ),
        metadata={
            "matched_terms": matched_terms,
            "commitment_status": commitment.get("status"),
            "subtype": "reported_completion",
        },
    )


def commitment_follow_up_signal(
    *,
    commitment: dict,
    last_checked_at: Optional[datetime],
) -> AccountabilitySignal:
    priority = bounded_int(commitment.get("priority"), default=3, minimum=1, maximum=5)
    title = str(commitment.get("title") or "Commitment").strip()
    text = str(commitment.get("commitment_text") or "").strip()

    return AccountabilitySignal(
        signal_type="upcoming_deadline",
        title=f"Commitment needs follow-up: {title}",
        summary=f"High-priority commitment has no recent check-in: {title}.",
        reason="High-priority open commitment has no due date or recent check-in.",
        severity="low",
        confidence=0.68,
        source_refs=[commitment_source_ref(commitment)],
        suggested_prompt=f"Quick check-in on this commitment: {text or title}.",
        recommended_action="Ask whether it is still active and what the next step is.",
        metadata={
            "subtype": "commitment_follow_up",
            "commitment_status": commitment.get("status"),
            "commitment_priority": priority,
            "last_checked_at": last_checked_at.isoformat()
            if last_checked_at
            else None,
        },
    )

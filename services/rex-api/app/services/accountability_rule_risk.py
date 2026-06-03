from app.models.accountability import AccountabilitySignal, AccountabilitySourceRef
from app.services.accountability_shared import (
    GENERIC_RULE_TERMS,
    NEGATION_TERMS,
    RULE_CATEGORY_TERMS,
    VIOLATION_ACTION_TERMS,
    bounded_int,
    contains_term,
    normalize_text,
    term_start_indexes,
    tokens,
)
from app.services.rule_service import is_active_rule


def detect_rule_violations(
    message: str,
    personal_rules: list[dict],
) -> list[AccountabilitySignal]:
    normalized_message = normalize_text(message)
    if not normalized_message:
        return []

    message_tokens = set(tokens(normalized_message))
    action_terms = sorted(message_tokens & VIOLATION_ACTION_TERMS)
    if not action_terms:
        return []

    signals = []
    for rule in personal_rules:
        if not is_active_rule(rule):
            continue

        matched_terms = matched_rule_terms(normalized_message, rule)
        if not matched_terms:
            continue
        if is_negated_or_preventive(normalized_message, matched_terms):
            continue

        signals.append(
            rule_violation_signal(
                rule=rule,
                matched_terms=matched_terms,
                action_terms=action_terms,
            )
        )
    return signals


def matched_rule_terms(normalized_message: str, rule: dict) -> list[str]:
    rule_terms_ = rule_terms(rule)
    return sorted(term for term in rule_terms_ if contains_term(normalized_message, term))


def rule_terms(rule: dict) -> set[str]:
    rule_type = str(rule.get("rule_type") or "").strip().lower()
    terms = set(RULE_CATEGORY_TERMS.get(rule_type, set()))
    terms.update(normalize_text(value) for value in rule.get("trigger_keywords") or [])

    rule_text = normalize_text(
        " ".join(str(rule.get(field) or "") for field in ("title", "rule_text"))
    )
    for term in GENERIC_RULE_TERMS:
        if contains_term(rule_text, term):
            terms.add(term)

    return {term for term in terms if term}


def is_negated_or_preventive(
    normalized_message: str,
    matched_terms: list[str],
) -> bool:
    message_tokens = tokens(normalized_message)
    for term in matched_terms:
        term_tokens = tokens(term)
        if not term_tokens:
            continue
        for index in term_start_indexes(message_tokens, term_tokens):
            window_start = max(index - 4, 0)
            window_end = min(index + len(term_tokens) + 3, len(message_tokens))
            nearby = set(message_tokens[window_start:window_end])
            if nearby & NEGATION_TERMS:
                return True
    return False


def rule_violation_signal(
    *,
    rule: dict,
    matched_terms: list[str],
    action_terms: list[str],
) -> AccountabilitySignal:
    priority = bounded_int(rule.get("priority"), default=3, minimum=1, maximum=5)
    severity = "high" if priority >= 5 else "medium" if priority >= 4 else "low"
    confidence = min(
        0.95,
        0.55
        + (0.12 if matched_terms else 0)
        + (0.12 if action_terms else 0)
        + (0.08 if priority >= 4 else 0),
    )
    rule_title = str(rule.get("title") or "Personal rule").strip()
    rule_text = str(rule.get("rule_text") or "").strip()
    matched_summary = ", ".join(matched_terms[:4])

    return AccountabilitySignal(
        signal_type="rule_violation",
        title=f"Possible rule violation: {rule_title}",
        summary=f"Current message appears to conflict with rule: {rule_title}.",
        reason=(
            "The message contains action language "
            f"({', '.join(action_terms[:3])}) and matched rule trigger(s): "
            f"{matched_summary}."
        ),
        severity=severity,
        confidence=round(confidence, 2),
        source_refs=[
            AccountabilitySourceRef(
                source_type="personal_rule",
                source_id=str(rule.get("id")) if rule.get("id") else None,
                title=rule_title,
                excerpt=rule_text or None,
            )
        ],
        suggested_prompt=(
            f"You said this rule matters: {rule_text or rule_title}. "
            "This sounds like the same pattern again."
        ),
        recommended_action=(
            "Ask whether the action already happened, then hold the user to "
            "the rule or help them recover cleanly."
        ),
        metadata={
            "rule_type": rule.get("rule_type"),
            "matched_terms": matched_terms,
            "action_terms": action_terms,
            "rule_priority": priority,
            "enforcement_style": rule.get("enforcement_style"),
        },
    )

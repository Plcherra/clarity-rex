"""Production proactive monitoring opt-in guard for SimpleRexBrain."""

from app.services.rex_brain_terms import PROACTIVE_MONITORING_TERMS, contains_any, normalize


def requires_proactive_monitoring_opt_in(
    message: str,
    *,
    user_enabled_proactive_insights: bool,
) -> bool:
    if user_enabled_proactive_insights:
        return False
    normalized = normalize(message)
    return contains_any(normalized, PROACTIVE_MONITORING_TERMS)


def proactive_monitoring_guard_text(*, requires_opt_in: bool) -> str:
    if not requires_opt_in:
        return ""
    return (
        "Proactive guard: only surface requested/enabled insights from provided "
        "context; do not imply monitoring. "
        "Ask opt-in before promising alerts or future notifications."
    )

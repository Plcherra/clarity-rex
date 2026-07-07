VOICE_LOW_TRANSCRIPT_CONFIDENCE_THRESHOLD = 0.75

VOICE_RESPONSE_MAX_TOKENS = 120
VOICE_DEEP_RESPONSE_MAX_TOKENS = 320
VOICE_DEEP_THINKING_PHRASES = (
    "deep think",
    "think deeply",
    "analyze thoroughly",
    "full analysis",
    "reason through",
    "go deeper",
    "deeper thinking",
)

_LOW_CONFIDENCE_INSTRUCTION = (
    "The latest voice transcript may be unreliable (low speech recognition "
    "confidence). Ask the user to repeat once before acting on unclear words "
    "or saving memory."
)


def voice_response_instructions(
    locale: str | None = None,
    transcript_confidence: float | None = None,
) -> str:
    from app.services.locale_utils import locale_response_rule

    parts: list[str] = []
    if (
        transcript_confidence is not None
        and transcript_confidence < VOICE_LOW_TRANSCRIPT_CONFIDENCE_THRESHOLD
    ):
        parts.append(_LOW_CONFIDENCE_INSTRUCTION)
    rule = locale_response_rule(locale)
    if rule:
        parts.append(rule)
    return "\n".join(parts)


def voice_response_max_tokens(transcript: str) -> int:
    normalized = transcript.lower()
    if any(phrase in normalized for phrase in VOICE_DEEP_THINKING_PHRASES):
        return VOICE_DEEP_RESPONSE_MAX_TOKENS
    return VOICE_RESPONSE_MAX_TOKENS

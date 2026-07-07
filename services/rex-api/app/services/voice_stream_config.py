VOICE_LOW_TRANSCRIPT_CONFIDENCE_THRESHOLD = 0.75

VOICE_RESPONSE_INSTRUCTIONS = (
    "Voice mode: reply in 1-2 short spoken sentences. Be warm, direct, and natural. "
    "Start with the answer, avoid filler, and keep wording easy to speak. "
    "If the transcript sounds unclear or garbled, ask one quick clarification before "
    "saving memory or making a correction. Use the same assistant truth rules as chat. "
    "Do not emit clarity_action blocks."
)
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


def voice_response_instructions(
    locale: str | None = None,
    transcript_confidence: float | None = None,
) -> str:
    from app.services.brain_prompt_policy import should_append_voice_instructions
    from app.services.locale_utils import locale_response_rule

    if not should_append_voice_instructions():
        return ""

    instructions = VOICE_RESPONSE_INSTRUCTIONS
    if (
        transcript_confidence is not None
        and transcript_confidence < VOICE_LOW_TRANSCRIPT_CONFIDENCE_THRESHOLD
    ):
        instructions = (
            "The latest voice transcript may be unreliable (low speech recognition "
            "confidence). Ask the user to repeat once before acting on unclear words "
            "or saving memory. "
            f"{instructions}"
        )
    rule = locale_response_rule(locale)
    if rule:
        return f"{instructions}\n{rule}"
    return instructions


def voice_response_max_tokens(transcript: str) -> int:
    normalized = transcript.lower()
    if any(phrase in normalized for phrase in VOICE_DEEP_THINKING_PHRASES):
        return VOICE_DEEP_RESPONSE_MAX_TOKENS
    return VOICE_RESPONSE_MAX_TOKENS

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


def voice_response_instructions(locale: str | None = None) -> str:
    from app.services.locale_utils import locale_response_rule

    rule = locale_response_rule(locale)
    if rule:
        return f"{VOICE_RESPONSE_INSTRUCTIONS}\n{rule}"
    return VOICE_RESPONSE_INSTRUCTIONS


def voice_response_max_tokens(transcript: str) -> int:
    normalized = transcript.lower()
    if any(phrase in normalized for phrase in VOICE_DEEP_THINKING_PHRASES):
        return VOICE_DEEP_RESPONSE_MAX_TOKENS
    return VOICE_RESPONSE_MAX_TOKENS

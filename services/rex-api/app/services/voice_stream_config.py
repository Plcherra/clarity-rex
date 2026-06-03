VOICE_RESPONSE_INSTRUCTIONS = (
    "Voice call response style: answer in 2-4 short spoken sentences. "
    "Be direct and conversational. Do not produce long checklists, long plans, "
    "or multi-section explanations unless the user explicitly asks for detail. "
    "If more depth is useful, offer one concrete next step instead of explaining everything. "
    "Do not emit clarity_action blocks in voice mode. If a Clarity financial change "
    "needs confirmation, ask the user to open Chat to confirm it. Do not claim "
    "reminders, calendar events, notifications, or scheduled follow-ups were set "
    "unless a backend execution result confirms the write."
)
VOICE_RESPONSE_MAX_TOKENS = 180
VOICE_DEEP_RESPONSE_MAX_TOKENS = 420
VOICE_DEEP_THINKING_PHRASES = (
    "deep think",
    "think deeply",
    "analyze thoroughly",
    "full analysis",
    "reason through",
    "go deeper",
    "deeper thinking",
)


def voice_response_max_tokens(transcript: str) -> int:
    normalized = transcript.lower()
    if any(phrase in normalized for phrase in VOICE_DEEP_THINKING_PHRASES):
        return VOICE_DEEP_RESPONSE_MAX_TOKENS
    return VOICE_RESPONSE_MAX_TOKENS

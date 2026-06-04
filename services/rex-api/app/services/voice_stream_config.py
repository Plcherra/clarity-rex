VOICE_RESPONSE_INSTRUCTIONS = (
    "Voice mode: reply in 1-3 short spoken sentences. Be warm, direct, and natural. "
    "Avoid lists or long explanations unless asked. Memory saves and corrections work in voice; "
    "acknowledge successful saves briefly. Do not emit clarity_action blocks. "
    "Never claim reminders, events, notifications, or financial changes completed unless "
    "execution metadata confirms success."
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

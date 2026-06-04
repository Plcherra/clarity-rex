MAX_CONTEXT_CHARACTERS = 24000
MAX_MEMORY_CONTEXT_CHARACTERS = 2000
MAX_STRUCTURED_MEMORY_CONTEXT_CHARACTERS = 3000
MAX_ACCOUNTABILITY_CONTEXT_CHARACTERS = 2200
MAX_FINANCIAL_CONTEXT_CHARACTERS = 14000
MAX_DEFAULT_REX_PROMPT_CHARACTERS = 1200
REX_PERSONALITY_PROMPT = (
    "Rex is Clarity's private, voice-first AI companion. Be direct, warm, "
    "honest, practical, and natural. Use saved memory and provided context when "
    "available, but never invent personal facts. For casual turns, answer fast "
    "and briefly. For sensitive financial, legal, tax, medical, immigration, or "
    "security topics, be careful, state limits, and avoid false certainty."
)
MEMORY_DISCIPLINE_PROMPT = (
    "Memory rules: simple durable facts can be acknowledged naturally and saved "
    "by the app. Corrections override older facts. Never claim a memory, "
    "reminder, goal, transaction, or other action was saved or changed unless "
    "backend execution metadata confirms success."
)
FILE_CONTEXT_PREFIX = "Uploaded file content:\n\n"
PERSONALITY_CONTEXT_PREFIX = "Rex personality and behavior:\n"
TIME_CONTEXT_PREFIX = "Current time context:\n"
CONVERSATION_CONTEXT_PREFIX = "Conversation context:\n"
STRUCTURED_MEMORY_PREFIX = "Relevant structured memory:\n"
ACCOUNTABILITY_CONTEXT_PREFIX = "Accountability context:\n"
FINANCIAL_CONTEXT_PREFIX = "Clarity financial summary:\n"
LONG_TERM_MEMORY_PREFIX = "Relevant long-term memory:\n"

"""Experimental layered Rex Brain term helpers.

NON-PRODUCTION FOR LAUNCH.

MVP production chat and voice use ChatService + SimpleRexBrain.
"""

import re


DEEP_PHRASES = (
    "deep think",
    "think deeply",
    "analyze thoroughly",
    "full analysis",
    "reason through",
    "what am i missing",
    "long term",
    "long-term",
)
ANALYTICAL_TERMS = (
    "analyze",
    "analysis",
    "calculate",
    "compare",
    "why",
    "budget",
    "spending",
    "spend",
    "income",
    "cash flow",
    "cashflow",
    "transaction",
    "tax",
    "debt",
    "investment",
    "forecast",
    "subscription",
    "category",
    "finance",
)
STRATEGIC_TERMS = (
    "plan",
    "strategy",
    "goal",
    "goals",
    "priority",
    "tradeoff",
    "trade-off",
    "choose",
    "roadmap",
    "next month",
    "next year",
    "milestone",
    "timeline",
)
SCENARIO_SIMULATION_TERMS = (
    "simulate",
    "simulation",
    "scenario",
    "what if",
    "if i",
    "if we",
    "payoff",
    "pay off",
    "debt payoff",
    "savings path",
    "spending tradeoff",
    "budget change",
    "cut spending",
    "reduce spending",
    "increase savings",
    "extra payment",
    "how long would it take",
    "projection",
)
PROACTIVE_INSIGHT_TERMS = (
    "insight",
    "insights",
    "unusual spending",
    "budget drift",
    "drift",
    "upcoming commitment",
    "upcoming commitments",
    "goal risk",
    "goal risks",
    "risk to my goal",
    "financial blind spot",
    "financial blind spots",
    "red flag",
    "red flags",
    "warning signs",
    "what should i watch",
    "watch this month",
    "what needs attention",
    "surface",
    "flag",
)
PROACTIVE_MONITORING_TERMS = (
    "monitor",
    "keep an eye",
    "alert me",
    "notify me",
    "warn me",
    "proactive",
    "automatically",
    "background",
    "every day",
    "daily",
    "weekly",
)
DAILY_FOCUS_TERMS = (
    "what should i focus on today",
    "what should i focus on",
    "focus today",
    "today's focus",
    "todays focus",
    "daily focus",
    "what should i do today",
    "what matters today",
    "next best action",
    "where should i put my attention",
    "what should my priorities be",
    "today's priorities",
    "todays priorities",
    "personal operating system",
)
PLANNING_WORKSPACE_TERMS = (
    "planning workspace",
    "planning session",
    "structured plan",
    "build a plan",
    "make a plan",
    "create a plan",
    "draft a plan",
    "resume the plan",
    "resume my plan",
    "continue the plan",
    "continue my plan",
    "edit the plan",
    "update the plan",
    "revise the plan",
    "adjust the plan",
    "change the plan",
    "plan workspace",
    "milestone plan",
)
PLANNING_WORKSPACE_CREATE_TERMS = (
    "build a plan",
    "make a plan",
    "create a plan",
    "draft a plan",
    "new plan",
    "planning session",
    "planning workspace",
)
PLANNING_WORKSPACE_RESUME_TERMS = (
    "resume the plan",
    "resume my plan",
    "continue the plan",
    "continue my plan",
    "pick up the plan",
    "go back to the plan",
)
PLANNING_WORKSPACE_EDIT_TERMS = (
    "edit the plan",
    "update the plan",
    "revise the plan",
    "adjust the plan",
    "change the plan",
    "modify the plan",
)
LONG_TERM_REVIEW_TERMS = (
    "long term intelligence review",
    "long-term intelligence review",
    "review my long term context",
    "review my long-term context",
    "review my stored context",
    "review stale goals",
    "review outdated memories",
    "review duplicate commitments",
    "find financial blind spots",
    "financial blind spots",
    "stale goals",
    "outdated memories",
    "duplicate commitments",
    "memory cleanup",
    "clean up my memory",
    "cleanup memory",
    "clean up my goals",
    "cleanup goals",
    "clean up commitments",
    "cleanup commitments",
    "audit my memory",
    "audit my goals",
    "audit my commitments",
    "audit my finances",
    "review my goals",
    "review my commitments",
    "what needs cleanup",
)
LONG_TERM_REVIEW_TARGET_TERMS = {
    "goals": (
        "goal",
        "goals",
        "stale goals",
        "audit my goals",
        "review my goals",
        "cleanup goals",
    ),
    "memories": (
        "memory",
        "memories",
        "outdated memories",
        "audit my memory",
        "clean up my memory",
        "memory cleanup",
    ),
    "commitments": (
        "commitment",
        "commitments",
        "duplicate commitments",
        "audit my commitments",
        "review my commitments",
        "cleanup commitments",
    ),
    "financial_blind_spots": (
        "finance",
        "finances",
        "financial",
        "financial blind spot",
        "financial blind spots",
        "audit my finances",
    ),
}
CONFIRMED_ACTION_TERMS = (
    "apply those changes",
    "apply these changes",
    "make those changes",
    "make these changes",
    "save those changes",
    "save these changes",
    "confirm those changes",
    "confirm these changes",
    "delete those",
    "delete these",
    "remove those",
    "remove these",
    "merge those",
    "merge these",
    "deactivate those",
    "deactivate these",
    "mark those",
    "mark these",
    "update those",
    "update these",
    "edit those",
    "edit these",
    "yes apply",
    "yes save",
    "yes delete",
    "yes remove",
    "yes merge",
    "go ahead and apply",
    "go ahead and save",
    "go ahead and delete",
    "go ahead and remove",
    "go ahead and merge",
)
CONFIRMED_ACTION_INTENT_TERMS = {
    "delete": (
        "delete those",
        "delete these",
        "remove those",
        "remove these",
        "yes delete",
        "yes remove",
        "go ahead and delete",
        "go ahead and remove",
    ),
    "merge": ("merge those", "merge these", "yes merge", "go ahead and merge"),
    "deactivate": (
        "deactivate those",
        "deactivate these",
        "archive those",
        "archive these",
    ),
    "update": (
        "update those",
        "update these",
        "edit those",
        "edit these",
        "make those changes",
        "make these changes",
        "apply those changes",
        "apply these changes",
        "yes apply",
        "go ahead and apply",
    ),
    "save": (
        "save those changes",
        "save these changes",
        "confirm those changes",
        "confirm these changes",
        "yes save",
        "go ahead and save",
    ),
    "complete": ("mark those", "mark these", "mark complete", "mark completed"),
}
CONFIRMED_ACTION_TARGET_TERMS = {
    "memories": ("memory", "memories", "preference", "preferences"),
    "goals": ("goal", "goals"),
    "commitments": ("commitment", "commitments", "pending item", "pending items"),
    "budgets": ("budget", "budgets"),
    "categories": ("category", "categories"),
    "rules": ("rule", "rules", "merchant rule", "merchant rules"),
    "transactions": ("transaction", "transactions"),
    "plans": ("plan", "plans", "planning workspace"),
}
ALLOWED_RESPONSE_STYLE_PROFILES = {
    "default",
    "coach",
    "analyst",
    "concise",
    "direct",
    "supportive",
}
RESPONSE_STYLE_TERMS = {
    "coach": (
        "coach mode",
        "coaching mode",
        "as my coach",
        "be my coach",
        "coach me",
    ),
    "analyst": (
        "analyst mode",
        "analysis mode",
        "as an analyst",
        "be analytical",
        "give me analyst",
    ),
    "concise": (
        "concise mode",
        "keep it concise",
        "be concise",
        "short answer",
        "brief answer",
        "quick answer",
    ),
    "direct": (
        "direct mode",
        "be direct",
        "tell me straight",
        "no sugarcoating",
        "straight answer",
    ),
    "supportive": (
        "supportive mode",
        "be supportive",
        "gentle tone",
        "encouraging tone",
        "soft tone",
    ),
}
REFLECTIVE_TERMS = (
    "check yourself",
    "double check",
    "verify",
    "critique",
    "contradiction",
    "consistent",
    "mistake",
    "wrong",
    "audit",
)
COACHING_TERMS = (
    "motivate",
    "motivation",
    "coach",
    "help me stay",
    "habit",
    "craving",
    "accountability",
    "encourage",
    "overwhelmed",
    "stuck",
)
MEMORY_TERMS = (
    "remember",
    "recall",
    "what did we decide",
    "what did i say",
    "last time",
    "before",
)
EXTERNAL_RESEARCH_TERMS = (
    "latest",
    "current",
    "recent",
    "news",
    "online",
    "internet",
    "web",
    "real-time",
    "real time",
    "up to date",
    "up-to-date",
    "right now",
    "look up",
    "search",
    "browse",
    "research",
    "verify online",
    "check online",
    "market rate",
    "price now",
)
RESEARCH_OPT_IN_TERMS = (
    "search",
    "look up",
    "browse",
    "research online",
    "check the web",
    "check online",
    "use the web",
    "use internet",
    "verify online",
    "go online",
)
SAFETY_SENSITIVE_TERMS = (
    "tax",
    "legal",
    "lawsuit",
    "irs",
    "bankruptcy",
    "medical",
    "diagnose",
)
CODE_TERMS = (
    "code",
    "debug",
    "stack trace",
    "exception",
    "function",
    "api",
    "sql",
)
CASUAL_PATTERN = re.compile(
    (
        r"^(hi|hey|hello|yo|thanks|thank you|ok|okay|cool|nice|lol|"
        r"good morning|good night)[!.\s]*$"
    ),
    re.IGNORECASE,
)


def normalize(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def contains_any(normalized: str, terms: tuple[str, ...]) -> bool:
    for term in terms:
        if " " in term or "-" in term:
            if term in normalized:
                return True
            continue
        if re.search(rf"\b{re.escape(term)}\b", normalized):
            return True
    return False


def looks_multi_step(normalized: str) -> bool:
    return bool(
        re.search(
            r"\b(first|second|third|then|after that|step by step)\b",
            normalized,
        )
        or normalized.count("?") >= 2
    )


def looks_like_recall(normalized: str) -> bool:
    return bool(re.search(r"\b(we|i) (decided|said|talked about)\b", normalized))

VALID_MEMORY_CATEGORIES = {
    "People",
    "Events",
    "Places",
    "Goals",
    "Preferences",
    "Facts",
    "Other",
}


def normalize_memory_category(value: object, *, default: str = "Other") -> str:
    if isinstance(value, str):
        normalized = value.strip().lower().replace("_", " ").replace("-", " ")
        aliases = {
            "people": "People",
            "person": "People",
            "events": "Events",
            "event": "Events",
            "places": "Places",
            "place": "Places",
            "goals": "Goals",
            "goal": "Goals",
            "preferences": "Preferences",
            "preference": "Preferences",
            "facts": "Facts",
            "fact": "Facts",
            "other": "Other",
        }
        if normalized in aliases:
            return aliases[normalized]
    return default if default in VALID_MEMORY_CATEGORIES else "Other"

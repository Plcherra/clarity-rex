PERSON_RELATIONSHIPS = {
    "mom": "mother",
    "mother": "mother",
    "mum": "mother",
    "mama": "mother",
    "dad": "father",
    "father": "father",
    "papa": "father",
}

SELF_LABELS = {"self", "user", "me", "myself"}
SELF_DISPLAY_FALLBACK = "User"

# Flat facts only become person cards at this importance. An explicit person
# save carries it as a floor so a confirmed card is always visible in Knows.
PERSON_CARD_MIN_IMPORTANCE = 4

UNSAFE_ALIAS_TERMS = {
    "account",
    "bank",
    "checking",
    "credit",
    "debit",
    "deposit",
    "deposits",
    "merchant",
    "payroll",
    "zelle",
}

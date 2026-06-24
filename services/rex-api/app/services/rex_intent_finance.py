from __future__ import annotations

import re

from app.services.rex_intent_patterns import FINANCE_TERMS, contains


class RexIntentFinanceHelper:
    def has_finance_language(self, normalized_message: str) -> bool:
        if contains(normalized_message, FINANCE_TERMS):
            return True
        if re.search(
            r"\$\s*\d|\b\d+(?:\.\d{2})?\s*(?:bucks|dollars)\b",
            normalized_message,
        ):
            return True
        if re.search(
            r"\b(?:what|which|show|list|display|see|view)\b.{0,30}\baccounts\b",
            normalized_message,
        ):
            return True
        if re.search(
            r"\baccounts?\b.{0,30}\b(?:balance|balances|connected|plaid|sync|synced)\b",
            normalized_message,
        ):
            return True
        money_nouns = (
            r"(?:money|cash|rent|bill|bills|dollar|dollars|paycheck|payroll|savings?)"
        )
        money_actions = (
            r"(?:afford|balance|bank|budget|charge|cost|deposit|earn|earned|hit|"
            r"owe|owed|paid|pay|paying|save|saved|saving|send|sending|sent|"
            r"spend|spending|spent|transfer|withdraw)"
        )
        return (
            re.search(
                rf"\b{money_actions}\b.{{0,40}}\b{money_nouns}\b",
                normalized_message,
            )
            is not None
            or re.search(
                rf"\b{money_nouns}\b.{{0,40}}\b{money_actions}\b",
                normalized_message,
            )
            is not None
        )

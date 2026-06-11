from __future__ import annotations

import re
from typing import Any, Optional


_CATEGORY_BY_PFC = {
    "BANK_FEES": "Fees & Interest",
    "ENTERTAINMENT": "Entertainment",
    "FOOD_AND_DRINK": "Food & Drink",
    "GENERAL_MERCHANDISE": "Shopping",
    "HOME_IMPROVEMENT": "Housing",
    "LOAN_PAYMENTS": "Credit Card Payment",
    "MEDICAL": "Pharmacy / Health",
    "RENT_AND_UTILITIES": "Housing",
    "SHOPS": "Shopping",
    "TRANSFER_IN": "Transfer In",
    "TRANSFER_OUT": "Transfer Out",
    "TRANSPORTATION": "Transportation",
    "TRAVEL": "Transportation",
}

_CATEGORY_BY_DETAILED_PFC = {
    "BANK_FEES_OVERDRAFT_FEES": "Fees & Interest",
    "BANK_FEES_OTHER_BANK_FEES": "Fees & Interest",
    "ENTERTAINMENT_MUSIC_AND_AUDIO": "Entertainment",
    "ENTERTAINMENT_SPORTING_EVENTS_AMUSEMENT_PARKS_AND_MUSEUMS": "Entertainment",
    "ENTERTAINMENT_TV_AND_MOVIES": "Entertainment",
    "FOOD_AND_DRINK_COFFEE": "Coffee / Quick Food",
    "FOOD_AND_DRINK_FAST_FOOD": "Coffee / Quick Food",
    "FOOD_AND_DRINK_GROCERIES": "Grocery / Supermarket",
    "GENERAL_MERCHANDISE_CLOTHING_AND_ACCESSORIES": "Shoes / Clothing",
    "GENERAL_MERCHANDISE_DEPARTMENT_STORES": "Shopping",
    "GENERAL_MERCHANDISE_DISCOUNT_STORES": "Shopping",
    "GENERAL_MERCHANDISE_ELECTRONICS": "Shopping",
    "GENERAL_MERCHANDISE_ONLINE_MARKETPLACES": "Shopping",
    "GENERAL_MERCHANDISE_PET_SUPPLIES": "Shopping",
    "GENERAL_MERCHANDISE_SPORTING_GOODS": "Shopping",
    "INCOME_WAGES": "Income / Payroll",
    "LOAN_PAYMENTS_CREDIT_CARD_PAYMENT": "Credit Card Payment",
    "MEDICAL_PHARMACIES_AND_SUPPLEMENTS": "Pharmacy / Health",
    "RENT_AND_UTILITIES_RENT": "Housing",
    "TRANSFER_IN_ACCOUNT_TRANSFER": "Transfer In",
    "TRANSFER_IN_CASH_ADVANCES_AND_LOANS": "Transfer In",
    "TRANSFER_IN_DEPOSIT": "Transfer In",
    "TRANSFER_IN_INVESTMENT_AND_RETIREMENT_FUNDS": "Transfer In",
    "TRANSFER_OUT_ACCOUNT_TRANSFER": "Transfer Out",
    "TRANSFER_OUT_INVESTMENT_AND_RETIREMENT_FUNDS": "Transfer Out",
    "TRANSFER_OUT_SAVINGS": "Transfer Out",
    "TRANSPORTATION_GAS": "Transportation",
    "TRANSPORTATION_PARKING": "Transportation",
    "TRANSPORTATION_PUBLIC_TRANSIT": "Transportation",
    "TRANSPORTATION_TAXIS_AND_RIDE_SHARES": "Transportation",
}


def normalized_category_key(raw: str) -> str:
    value = raw.strip().lower().replace("&", " and ")
    value = re.sub(r"[^a-z0-9]+", " ", value)
    value = re.sub(r"\band\b", " ", value)
    value = re.sub(r"\s+", " ", value)
    return value.strip()


def clarity_category_for_plaid_transaction(
    transaction: dict[str, Any],
) -> Optional[str]:
    description = _text(transaction.get("merchant_name")) or _text(transaction.get("name"))
    description_lower = description.lower()
    amount = _number_or_zero(transaction.get("amount"))

    keyword_category = _category_for_keywords(description_lower, amount=amount)
    if keyword_category:
        return keyword_category

    personal_finance = transaction.get("personal_finance_category")
    if isinstance(personal_finance, dict):
        detailed = _text(personal_finance.get("detailed")).upper()
        primary = _text(personal_finance.get("primary")).upper()
        if detailed in _CATEGORY_BY_DETAILED_PFC:
            return _CATEGORY_BY_DETAILED_PFC[detailed]
        if primary in _CATEGORY_BY_PFC:
            return _CATEGORY_BY_PFC[primary]

    if amount < 0:
        return "Income / Payroll"
    return None


def _category_for_keywords(description_lower: str, *, amount: float) -> Optional[str]:
    if "interest" in description_lower:
        if amount < 0:
            return "Income / Interest"
        return "Fees & Interest"
    if any(token in description_lower for token in ("payroll", "direct dep", "salary")):
        return "Income / Payroll"
    if "zelle" in description_lower and amount < 0:
        return "Income / Zelle Received"
    if any(token in description_lower for token in ("credit card payment", "cc payment")):
        return "Credit Card Payment"
    if any(token in description_lower for token in ("overdraft protection", "account transfer")):
        return "Transfer Out" if amount >= 0 else "Transfer In"
    if any(token in description_lower for token in ("uber", "lyft", "mbta", "gas", "parking")):
        return "Transportation"
    if any(token in description_lower for token in ("cvs", "walgreens", "pharmacy")):
        return "Pharmacy / Health"
    if any(token in description_lower for token in ("market", "grocery", "supermarket")):
        return "Grocery / Supermarket"
    if any(
        token in description_lower
        for token in ("dunkin", "starbucks", "coffee", "bom dough", "tst*")
    ):
        return "Coffee / Quick Food"
    if any(
        token in description_lower
        for token in ("cursor", "11labs", "11 labs", "hetzner", "hasner")
    ):
        return "Subscriptions"
    if any(token in description_lower for token in ("apple.com/bill", "google *", "youtube")):
        return "Subscriptions"
    if any(token in description_lower for token in ("gog.com", "gog ")):
        return "Shopping"
    if any(token in description_lower for token in ("amc ", "amc theatre", "amc online")):
        return "Entertainment"
    if any(token in description_lower for token in ("rent", "mortgage")):
        return "Housing"
    return None


def _text(value: Any) -> str:
    return value.strip() if isinstance(value, str) else ""


def _number_or_zero(value: Any) -> float:
    if isinstance(value, bool):
        return 0
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0

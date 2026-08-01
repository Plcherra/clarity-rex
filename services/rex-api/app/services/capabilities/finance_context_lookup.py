"""Read-only lookups over the mobile-provided financial context pack.

Used by the finance fetch pack builders and by mutate proposals that must turn
names the user said ("coffee", "Starbucks") into the ids `/clarity/actions`
needs. Never invents records: every value comes from the pack the app sent.
"""

from __future__ import annotations

from typing import Any, Optional

from app.services.category_name_normalization import categories_match


def context_dict(financial_context: Optional[dict], key: str) -> dict:
    if not isinstance(financial_context, dict):
        return {}
    value = financial_context.get(key)
    return value if isinstance(value, dict) else {}


def context_list(financial_context: Optional[dict], key: str) -> list[dict]:
    if not isinstance(financial_context, dict):
        return []
    value = financial_context.get(key)
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]


def find_category(
    financial_context: Optional[dict],
    name: Optional[str],
) -> Optional[dict]:
    if not name:
        return None
    categories = context_list(financial_context, "categories")
    # Prefer the plural-aware key so "work reimbursement" finds
    # "Work Reimbursements" before a looser substring match does.
    for record in categories:
        for key in ("normalized_name", "name"):
            value = str(record.get(key) or "").strip()
            if value and categories_match(name, value):
                return record
    return _best_match(categories, name, keys=("name", "normalized_name"))


def find_budget(
    financial_context: Optional[dict],
    reference: Optional[str],
    *,
    category_name: Optional[str] = None,
) -> Optional[dict]:
    budgets = context_list(financial_context, "budgets")
    match = _best_match(budgets, reference, keys=("name", "category_key"))
    if match is not None:
        return match
    category = find_category(financial_context, category_name)
    if category is None:
        return None
    category_id = str(category.get("id") or "")
    for budget in budgets:
        if category_id and str(budget.get("category_id") or "") == category_id:
            return budget
    return _best_match(budgets, category_name, keys=("name", "category_key"))


def find_account(
    financial_context: Optional[dict],
    reference: Optional[str],
) -> Optional[dict]:
    accounts = context_list(financial_context, "accounts")
    if not reference:
        return None
    for account in accounts:
        if str(account.get("id") or "") == reference:
            return account
    return _best_match(
        accounts,
        reference,
        keys=("name", "display_name", "institution", "mask"),
    )


def transaction_coverage(financial_context: Optional[dict]) -> Optional[str]:
    """Describe missing transaction detail, or None when the pack holds it all.

    The app sends recent and query-matched rows rather than every transaction,
    and trims further when the pack would exceed the request size limit. Saying
    so keeps "nothing matched" from reading as "you never spent that".
    """
    integration = context_dict(financial_context, "integration")
    period = context_dict(financial_context, "period")
    included = _count(period.get("included_transaction_count"))
    total = _count(period.get("transaction_count"))
    parts: list[str] = []
    if included is not None and total is not None and included < total:
        parts.append(f"{included} of {total} transactions this period")
    elif str(integration.get("raw_transactions_included")).lower() == "false":
        parts.append("recent and matching rows only")
    if str(integration.get("size_capped")).lower() == "true":
        reason = str(integration.get("size_cap_reason") or "size limit").strip()
        parts.append(f"trimmed to fit the request size limit ({reason})")
    if not parts:
        return None
    return "; ".join(parts)


def merchant_month_rollups(
    financial_context: Optional[dict],
    merchant: Optional[str],
) -> list[dict]:
    """Whole-period spend per merchant, from Clarity's own category rollups.

    Transaction rows in the pack are a recent sample, so counting them
    undercounts a merchant the user visits daily. These rollups cover the full
    period and stay small enough to always travel with the pack.
    """
    wanted = str(merchant or "").strip().lower()
    if not wanted:
        return []
    rollups: list[dict] = []
    for category in context_list(financial_context, "category_spend_this_month"):
        entries = category.get("top_merchants")
        if not isinstance(entries, list):
            continue
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            label = str(entry.get("merchant") or entry.get("name") or "").strip()
            if not label:
                continue
            lowered = label.lower()
            if wanted not in lowered and lowered not in wanted:
                continue
            rollups.append(
                {
                    "merchant": label,
                    "category": str(category.get("category") or "").strip(),
                    "spent": entry.get("spent"),
                    "transaction_count": entry.get("transaction_count"),
                }
            )
    return rollups


def matching_transactions(
    financial_context: Optional[dict],
    *,
    merchant: Optional[str] = None,
    category: Optional[str] = None,
    account_id: Optional[str] = None,
    limit: Optional[int] = None,
) -> list[dict]:
    rows = _all_transactions(financial_context)
    matches: list[dict] = []
    for row in rows:
        if account_id and str(row.get("account_id") or "") != account_id:
            continue
        if merchant and not _row_mentions(
            row,
            merchant,
            keys=("merchant", "description", "account_name"),
        ):
            continue
        if category and not _row_mentions(
            row,
            category,
            keys=("category_name", "stored_category_name"),
        ):
            continue
        matches.append(row)
    if limit is not None:
        return matches[:limit]
    return matches


def transaction_ids(rows: list[dict]) -> list[str]:
    ids: list[str] = []
    for row in rows:
        value = str(row.get("id") or "").strip()
        if value and value not in ids:
            ids.append(value)
    return ids


def spend_total(rows: list[dict]) -> Optional[float]:
    total = 0.0
    seen = False
    for row in rows:
        amount = _amount(row)
        if amount is None:
            continue
        seen = True
        total += abs(amount)
    return round(total, 2) if seen else None


def transaction_line(row: dict) -> str:
    parts = [str(row.get("date") or "").strip()]
    label = str(row.get("merchant") or row.get("description") or "").strip()
    if label:
        parts.append(label)
    amount = _amount(row)
    if amount is not None:
        parts.append(f"{abs(amount):.2f}")
    category = str(row.get("category_name") or "").strip()
    if category:
        parts.append(f"[{category}]")
    return " ".join(part for part in parts if part)


def _all_transactions(financial_context: Optional[dict]) -> list[dict]:
    rows = context_list(financial_context, "matched_transactions")
    seen = {str(row.get("id") or "") for row in rows}
    for row in context_list(financial_context, "transactions"):
        if str(row.get("id") or "") in seen:
            continue
        rows.append(row)
    return rows


def _count(value: Any) -> Optional[int]:
    if value is None or isinstance(value, (list, dict, bool)):
        return None
    try:
        return int(float(str(value)))
    except ValueError:
        return None


def _amount(row: dict) -> Optional[float]:
    for key in ("signed_amount", "amount"):
        value = row.get(key)
        if value is None or isinstance(value, (list, dict, bool)):
            continue
        try:
            return float(str(value))
        except ValueError:
            continue
    return None


def _row_mentions(row: dict, needle: str, *, keys: tuple[str, ...]) -> bool:
    wanted = needle.strip().lower()
    if not wanted:
        return False
    for key in keys:
        value = str(row.get(key) or "").strip().lower()
        if value and (wanted in value or value in wanted):
            return True
    return False


def _best_match(
    records: list[dict],
    needle: Optional[str],
    *,
    keys: tuple[str, ...],
) -> Optional[dict]:
    wanted = str(needle or "").strip().lower()
    if not wanted:
        return None
    partial: Optional[dict] = None
    for record in records:
        for key in keys:
            value = str(record.get(key) or "").strip().lower()
            if not value:
                continue
            if value == wanted:
                return record
            if partial is None and (wanted in value or value in wanted):
                partial = record
    return partial


def value_or_none(value: Any) -> Optional[str]:
    text = str(value or "").strip()
    return text or None

#!/usr/bin/env python3
"""One-time cleanup for old budgets with no active transactions.

This script is intentionally narrow: it uses the Supabase service role from
services/rex-api/.env, scopes cleanup to one profile email, and never reads or
prints transaction descriptions.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / "services" / "rex-api" / ".env"


def load_env(path: Path) -> None:
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


def request_json(
    method: str,
    path: str,
    *,
    params: dict[str, str] | None = None,
    body: Any | None = None,
) -> Any:
    base = os.environ["SUPABASE_URL"].rstrip("/")
    service_key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    query = urllib.parse.urlencode(params or {}, safe="(),.*")
    url = f"{base}/rest/v1/{path}"
    if query:
        url = f"{url}?{query}"
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read().decode("utf-8")
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Supabase {method} {path} failed: {exc.code} {detail}") from exc


def normalized_category_key(raw: str) -> str:
    value = raw.strip().lower().replace("&", " and ")
    value = re.sub(r"[^a-z0-9]+", " ", value)
    value = re.sub(r"\band\b", " ", value)
    value = re.sub(r"\s+", " ", value)
    return value.strip()


def category_key(category: dict[str, Any]) -> str:
    normalized = str(category.get("normalized_name") or "").strip()
    return normalized or normalized_category_key(str(category.get("name") or ""))


def budget_key(budget: dict[str, Any], category: dict[str, Any] | None) -> str:
    stored = str(budget.get("category_key") or "").strip()
    if stored:
        return stored
    if category is not None:
        return category_key(category)
    return normalized_category_key(str(budget.get("name") or ""))


def fetch_profile(email: str) -> dict[str, Any]:
    rows = request_json(
        "GET",
        "profiles",
        params={"select": "id,email", "email": f"eq.{email}", "limit": "1"},
    )
    if not rows:
        raise RuntimeError(f"No profile found for {email}.")
    return rows[0]


def fetch_rows(table: str, user_id: str, select: str) -> list[dict[str, Any]]:
    rows = request_json(
        "GET",
        table,
        params={"select": select, "user_id": f"eq.{user_id}"},
    )
    return list(rows or [])


def find_orphan_budgets(user_id: str) -> list[dict[str, Any]]:
    budgets = fetch_rows(
        "budgets",
        user_id,
        "id,user_id,name,category_id,category_key,period,start_date",
    )
    categories = fetch_rows(
        "categories",
        user_id,
        "id,user_id,name,normalized_name,hidden,type",
    )
    transactions = fetch_rows(
        "transactions",
        user_id,
        "id,user_id,category_id,removed_at",
    )

    category_by_id = {row["id"]: row for row in categories}
    category_by_key = {category_key(row): row for row in categories}
    active_category_ids = {
        str(row.get("category_id"))
        for row in transactions
        if row.get("category_id") and row.get("removed_at") is None
    }
    active_category_keys = {
        category_key(category_by_id[category_id])
        for category_id in active_category_ids
        if category_id in category_by_id
    }

    orphaned: list[dict[str, Any]] = []
    for budget in budgets:
        category_id = str(budget.get("category_id") or "").strip()
        category = category_by_id.get(category_id)
        if category is None:
            key = str(budget.get("category_key") or "").strip()
            if key:
                category = category_by_key.get(key)
        if category_id and category_id in active_category_ids:
            continue
        if category is not None and category["id"] in active_category_ids:
            continue
        if budget_key(budget, category) in active_category_keys:
            continue
        orphaned.append(budget)
    return orphaned


def delete_budget(user_id: str, budget_id: str) -> None:
    request_json(
        "DELETE",
        "budgets",
        params={"user_id": f"eq.{user_id}", "id": f"eq.{budget_id}"},
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--email", default="plcherra@gmail.com")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    load_env(ENV_PATH)
    missing = [
        key
        for key in ("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY")
        if not os.environ.get(key)
    ]
    if missing:
        print(f"Missing required env keys: {', '.join(missing)}", file=sys.stderr)
        return 2

    profile = fetch_profile(args.email)
    user_id = profile["id"]
    orphaned = find_orphan_budgets(user_id)

    mode = "APPLY" if args.apply else "DRY RUN"
    print(f"{mode}: found {len(orphaned)} orphan budget(s) for {args.email}.")
    for budget in orphaned:
        print(f"- {budget['name']} ({budget['period']})")

    if args.apply:
        for budget in orphaned:
            delete_budget(user_id, budget["id"])
        remaining = find_orphan_budgets(user_id)
        print(f"Cleanup complete. Remaining orphan budget(s): {len(remaining)}.")
        return 1 if remaining else 0

    print("Run again with --apply to delete these budgets.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

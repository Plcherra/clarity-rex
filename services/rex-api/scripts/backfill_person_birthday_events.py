#!/usr/bin/env python3
"""One-time backfill: orphan birthday Event flats → Knows person cards.

Does not create chat turns. Reuses PersonMemoryMaterializer + consolidator.

Usage (from services/rex-api, with env loaded):

  # Dry-run (default) — report only
  python scripts/backfill_person_birthday_events.py

  # Apply for the service-role default user context
  python scripts/backfill_person_birthday_events.py --apply

  # Scoped to one user
  python scripts/backfill_person_birthday_events.py --user-id USER_ID --apply
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


async def _main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Backfill active birthday Event flats into person cards "
            "(dry-run by default)."
        )
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write person cards and hard-delete covered flats.",
    )
    parser.add_argument("--limit", type=int, default=250)
    parser.add_argument(
        "--user-id",
        default=None,
        help="Optional user id for SupabaseMemoryService scoping.",
    )
    args = parser.parse_args()

    from app.services.http_client import shutdown_http_client, startup_http_client
    from app.services.memory_service import SupabaseMemoryService
    from app.services.person_birthday_backfill import PersonBirthdayBackfillService

    await startup_http_client()
    try:
        if args.user_id:
            memory_service = SupabaseMemoryService(
                user_id=args.user_id,
                access_token="service",
            )
        else:
            memory_service = SupabaseMemoryService()
        report = await PersonBirthdayBackfillService().run(
            memory_service,
            apply=args.apply,
            limit=args.limit,
        )
        print(json.dumps(report.as_dict(), indent=2, sort_keys=True))
    finally:
        await shutdown_http_client()


if __name__ == "__main__":
    asyncio.run(_main())

"""One-off repair: split malformed numbered-list goal bodies into separate plans."""

from __future__ import annotations

import argparse
import asyncio
import json
from dataclasses import dataclass, field
from typing import Any

from app.models.plan import PlanCreateRequest
from app.services.body_display_text import goal_title, normalize_equipment_goal_title, plan_type
from app.services.goal_repair_helpers import is_malformed_numbered_goal, split_plan_bodies
from app.services.http_client import shutdown_http_client, startup_http_client
from app.services.memory_service import SupabaseMemoryService
from app.services.plan_service import PlanService


@dataclass
class GoalRepairReport:
    dry_run: bool
    scanned: int = 0
    candidates: list[dict[str, Any]] = field(default_factory=list)
    created: list[dict[str, Any]] = field(default_factory=list)
    archived: list[dict[str, Any]] = field(default_factory=list)
    skipped: list[dict[str, str]] = field(default_factory=list)
    errors: list[dict[str, str]] = field(default_factory=list)

    def as_dict(self) -> dict[str, Any]:
        return {
            "dry_run": self.dry_run,
            "scanned": self.scanned,
            "candidates": self.candidates,
            "created": self.created,
            "archived": self.archived,
            "skipped": self.skipped,
            "errors": self.errors,
        }


async def repair_malformed_goals(
    memory_service: SupabaseMemoryService,
    *,
    apply: bool = False,
    limit: int = 200,
) -> GoalRepairReport:
    report = GoalRepairReport(dry_run=not apply)
    plan_service = PlanService(memory_service)
    plans = await memory_service.list_plans(active=True, limit=limit)
    report.scanned = len(plans)

    for plan in plans:
        if not is_malformed_numbered_goal(plan):
            continue
        items = split_plan_bodies(plan)
        if len(items) < 2:
            report.skipped.append(
                {
                    "plan_id": str(plan.get("id") or ""),
                    "reason": "could_not_split",
                }
            )
            continue

        preview = {
            "plan_id": str(plan.get("id") or ""),
            "original_title": str(plan.get("title") or ""),
            "split_items": items,
        }
        report.candidates.append(preview)
        if not apply:
            continue

        plan_id = str(plan.get("id") or "")
        try:
            for item in items:
                created = await plan_service.create_plan(
                    PlanCreateRequest(
                        plan_type=plan_type(item),
                        title=goal_title(normalize_equipment_goal_title(item)),
                        description=item,
                        desired_outcome=item,
                        source_conversation_id=plan.get("source_conversation_id"),
                        target_date=plan.get("target_date"),
                        priority=int(plan.get("priority") or 4),
                        metadata={
                            "source": "repair_malformed_goals",
                            "repaired_from_plan_id": plan_id,
                        },
                    )
                )
                report.created.append(
                    {
                        "id": created.get("id"),
                        "title": created.get("title"),
                        "repaired_from_plan_id": plan_id,
                    }
                )
            archived = await memory_service.deactivate_plan(plan_id)
            if archived:
                report.archived.append({"id": plan_id, "title": plan.get("title")})
            else:
                report.errors.append(
                    {
                        "plan_id": plan_id,
                        "message": "Split goals created but original plan was not archived.",
                    }
                )
        except Exception as error:
            report.errors.append(
                {
                    "plan_id": plan_id,
                    "message": str(error),
                }
            )

    return report


async def _main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Persist repairs. Default is dry-run preview only.",
    )
    parser.add_argument("--limit", type=int, default=200)
    args = parser.parse_args()

    await startup_http_client()
    try:
        memory_service = SupabaseMemoryService(use_service_role=True)
        report = await repair_malformed_goals(
            memory_service,
            apply=args.apply,
            limit=args.limit,
        )
        print(json.dumps(report.as_dict(), indent=2))
    finally:
        await shutdown_http_client()


if __name__ == "__main__":
    asyncio.run(_main())

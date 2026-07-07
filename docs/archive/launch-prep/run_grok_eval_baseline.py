#!/usr/bin/env python3
"""Run Plan 03 Phase 1 baseline eval through production ChatService + real Grok.

Usage (from services/rex-api, with .env containing GROK_API_KEY + GROK_MODEL):

    python ../../docs/archive/launch-prep/run_grok_eval_baseline.py

Prints JSON per turn to stdout. Paste results into grok-eval-baseline.md.
"""

from __future__ import annotations

import asyncio
import json
import sys
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

REX_API_ROOT = Path(__file__).resolve().parents[3] / "services" / "rex-api"
if str(REX_API_ROOT) not in sys.path:
    sys.path.insert(0, str(REX_API_ROOT))
TESTS_ROOT = REX_API_ROOT / "tests"
if str(TESTS_ROOT) not in sys.path:
    sys.path.insert(0, str(TESTS_ROOT))

from app.config import get_settings  # noqa: E402
from app.services.ai_service import AIService  # noqa: E402
from app.services.chat_service import ChatService  # noqa: E402
from app.services.chat_turn_observability import ChatTurnObserver  # noqa: E402
from app.services.file_service import FileService  # noqa: E402
from app.services.time_context_service import TimeContextService  # noqa: E402
from chat_service_fakes import FakeMemoryService  # noqa: E402

EVAL_TURNS = [
    "I'm choosing between two sport bikes — one brand I love, one that's probably smarter. Thoughts?",
    "I haven't ridden in ten years.",
    "This would be my first bike.",
    "I care more about how it looks and how I feel on it than being sensible.",
    "Which would you pick?",
    "What did we say about my first bike?",
]


class CapturingTurnObserver(ChatTurnObserver):
    def __init__(self) -> None:
        super().__init__()
        self.logged: list[dict] = []

    def log_turn(self, trace):
        payload = super().log_turn(trace)
        self.logged.append(payload)
        return payload


def _fixed_time_context_service() -> TimeContextService:
    return TimeContextService(
        timezone_name="America/New_York",
        now_provider=lambda: datetime(
            2026,
            7,
            6,
            12,
            0,
            tzinfo=ZoneInfo("America/New_York"),
        ),
    )


def _write_proposals(result: dict) -> list:
    memory_changes = result.get("memory_changes") or {}
    return list(memory_changes.get("write_proposals") or [])


async def run_eval() -> list[dict]:
    settings = get_settings()
    if not settings.grok_api_key:
        raise SystemExit(
            "GROK_API_KEY not set. Copy services/rex-api/.env.example to .env and fill keys."
        )

    observer = CapturingTurnObserver()
    chat_service = ChatService(
        AIService(settings),
        FileService(),
        FakeMemoryService(),
        time_context_service=_fixed_time_context_service(),
    )
    chat_service.turn_orchestrator.turn_observer = observer

    conversation_id = None
    results: list[dict] = []

    for index, user_message in enumerate(EVAL_TURNS, start=1):
        trace_before = len(observer.logged)
        result = await chat_service.send_message(
            user_message,
            conversation_id=conversation_id,
            financial_context=None,
        )
        conversation_id = result["conversation_id"]
        trace = observer.logged[-1] if len(observer.logged) > trace_before else {}
        results.append(
            {
                "turn": index,
                "user_message": user_message,
                "assistant_response": result.get("response") or "",
                "write_proposals": _write_proposals(result),
                "intent": trace.get("intent"),
                "handler": trace.get("handler"),
            }
        )

    return results


def main() -> None:
    results = asyncio.run(run_eval())
    print(json.dumps(results, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()

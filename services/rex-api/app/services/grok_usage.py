from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Optional


@dataclass(frozen=True)
class GrokUsage:
    prompt_tokens: int = 0
    completion_tokens: int = 0
    cost_in_usd_ticks: int | None = None

    @property
    def total_tokens(self) -> int:
        return self.prompt_tokens + self.completion_tokens

    def cost_cents(self) -> float | None:
        if self.cost_in_usd_ticks is None or self.cost_in_usd_ticks <= 0:
            return None
        return self.cost_in_usd_ticks / 100_000_000.0

    @classmethod
    def from_api_payload(cls, data: Any) -> Optional[GrokUsage]:
        if not isinstance(data, dict):
            return None
        usage = data.get("usage")
        if not isinstance(usage, dict):
            return None
        prompt = _non_negative_int(usage.get("prompt_tokens"))
        if prompt is None:
            prompt = _non_negative_int(usage.get("input_tokens"))
        completion = _non_negative_int(usage.get("completion_tokens"))
        if completion is None:
            completion = _non_negative_int(usage.get("output_tokens"))
        total = _non_negative_int(usage.get("total_tokens"))
        cost_ticks = _non_negative_int(usage.get("cost_in_usd_ticks"))
        if (
            prompt is None
            and completion is None
            and total is None
            and cost_ticks is None
        ):
            return None
        if prompt is None and completion is None and total is not None:
            return cls(
                prompt_tokens=0,
                completion_tokens=total,
                cost_in_usd_ticks=cost_ticks,
            )
        return cls(
            prompt_tokens=prompt or 0,
            completion_tokens=completion or 0,
            cost_in_usd_ticks=cost_ticks,
        )


@dataclass
class GrokUsageHolder:
    usage: GrokUsage | None = None


@dataclass(frozen=True)
class GrokChatResult:
    text: str
    usage: GrokUsage | None = None


def _non_negative_int(value: Any) -> int | None:
    if value is None:
        return None
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return None
    return parsed if parsed >= 0 else None

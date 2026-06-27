from __future__ import annotations

from app.config import Settings


def estimate_usage_cost_cents(
    *,
    event_type: str,
    unit_count: float | None = None,
    duration_ms: int | None = None,
    prompt_tokens: int | None = None,
    completion_tokens: int | None = None,
    character_count: int | None = None,
    settings: Settings,
) -> float | None:
    if event_type == "llm":
        return estimate_llm_cost_cents(
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            total_tokens=_token_total(unit_count, prompt_tokens, completion_tokens),
            settings=settings,
        )

    if event_type == "stt":
        rate = settings.usage_deepgram_cents_per_minute
        minutes = _duration_minutes(duration_ms)
        if rate <= 0 or minutes is None:
            return None
        return round(minutes * rate, 6)

    if event_type == "tts":
        return estimate_tts_cost_cents(
            character_count=character_count,
            duration_ms=duration_ms,
            settings=settings,
        )

    return None


def estimate_llm_cost_cents(
    *,
    prompt_tokens: int | None,
    completion_tokens: int | None,
    total_tokens: int | None,
    settings: Settings,
) -> float | None:
    input_rate = settings.usage_grok_input_cents_per_1k_tokens
    output_rate = settings.usage_grok_output_cents_per_1k_tokens
    blended_rate = settings.usage_grok_cents_per_1k_tokens

    prompt = prompt_tokens or 0
    completion = completion_tokens or 0
    if prompt > 0 and completion > 0 and (input_rate > 0 or output_rate > 0):
        return round(
            (prompt / 1000.0) * max(input_rate, 0.0)
            + (completion / 1000.0) * max(output_rate, 0.0),
            6,
        )

    total = total_tokens or (prompt + completion)
    if total <= 0:
        return None
    if blended_rate > 0:
        return round((total / 1000.0) * blended_rate, 6)
    if input_rate > 0 or output_rate > 0:
        return round(
            (total / 1000.0) * (0.4 * max(input_rate, 0.0) + 0.6 * max(output_rate, 0.0)),
            6,
        )
    return None


def estimate_tts_cost_cents(
    *,
    character_count: int | None,
    duration_ms: int | None,
    settings: Settings,
) -> float | None:
    char_rate = settings.usage_tts_cents_per_1k_chars
    if character_count is not None and character_count > 0 and char_rate > 0:
        return round((character_count / 1000.0) * char_rate, 6)

    minute_rate = settings.usage_tts_cents_per_minute
    minutes = _duration_minutes(duration_ms)
    if minute_rate <= 0 or minutes is None:
        return None
    return round(minutes * minute_rate, 6)


def llm_unit_count(token_count: int | None) -> float | None:
    if token_count is None or token_count <= 0:
        return None
    return float(token_count)


def duration_unit_minutes(duration_ms: int | None) -> float | None:
    return _duration_minutes(duration_ms)


def _token_total(
    unit_count: float | None,
    prompt_tokens: int | None,
    completion_tokens: int | None,
) -> int | None:
    if unit_count is not None and unit_count > 0:
        return int(round(unit_count))
    total = (prompt_tokens or 0) + (completion_tokens or 0)
    return total if total > 0 else None


def _duration_minutes(duration_ms: int | None) -> float | None:
    if duration_ms is None or duration_ms <= 0:
        return None
    return duration_ms / 60_000.0

from __future__ import annotations

from typing import Any


def slice_label_key(
    *,
    provider: str | None,
    feature: str | None,
    channel: str | None,
    event_type: str | None,
) -> str:
    provider_key = (provider or "").strip().lower()
    channel_key = (channel or "").strip().lower()
    event_key = (event_type or "").strip().lower()
    _ = feature
    if provider_key == "grok" and event_key == "llm" and channel_key == "chat":
        return "grok_chat"
    if provider_key == "grok" and event_key == "llm":
        return "grok_voice"
    if provider_key in {"google_tts", "google"} and event_key == "tts":
        return "google_tts"
    if provider_key == "deepgram" and event_key == "stt":
        return "deepgram_stt"
    if "deepgram" in provider_key and event_key == "tts":
        return "deepgram_tts"
    if event_key == "voice_session":
        return "voice_session"
    if provider_key == "plaid":
        return "plaid"
    return "other"


def slice_id(
    *,
    provider: str,
    feature: str,
    channel: str,
    event_type: str,
) -> str:
    return f"{provider}:{feature}:{channel}:{event_type}"


def empty_slice(
    *,
    provider: str,
    feature: str,
    channel: str,
    event_type: str,
) -> dict[str, Any]:
    return {
        "id": slice_id(
            provider=provider,
            feature=feature,
            channel=channel,
            event_type=event_type,
        ),
        "label_key": slice_label_key(
            provider=provider,
            feature=feature,
            channel=channel,
            event_type=event_type,
        ),
        "provider": provider,
        "feature": feature,
        "channel": channel,
        "event_type": event_type,
        "event_count": 0,
        "unit_count": 0.0,
        "duration_ms": 0,
        "estimated_cost_cents": 0.0,
        "share": 0.0,
        "metered": False,
    }


def add_event_to_bucket(
    buckets: dict[str, dict[str, Any]],
    row: dict[str, Any],
) -> None:
    provider = _text(row.get("provider"), "unknown")
    feature = _text(row.get("feature"), "unknown")
    channel = _text(row.get("channel"), "unknown")
    event_type = _text(row.get("event_type"), "unknown")
    key = slice_id(
        provider=provider,
        feature=feature,
        channel=channel,
        event_type=event_type,
    )
    bucket = buckets.setdefault(
        key,
        empty_slice(
            provider=provider,
            feature=feature,
            channel=channel,
            event_type=event_type,
        ),
    )
    bucket["event_count"] += 1
    bucket["unit_count"] += _float(row.get("unit_count"))
    bucket["duration_ms"] += int(_float(row.get("duration_ms")))
    bucket["estimated_cost_cents"] += _float(row.get("estimated_cost_cents"))


def finalize_slices(buckets: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    slices = [dict(item) for item in buckets.values()]
    metered_total = sum(
        float(item["estimated_cost_cents"])
        for item in slices
        if float(item["estimated_cost_cents"]) > 0
    )
    for item in slices:
        cost = float(item["estimated_cost_cents"])
        item["estimated_cost_cents"] = round(cost, 6)
        item["unit_count"] = round(float(item["unit_count"]), 4)
        item["metered"] = cost > 0
        item["share"] = round(cost / metered_total, 4) if metered_total > 0 and cost > 0 else 0.0
    slices.sort(
        key=lambda item: (
            -float(item["estimated_cost_cents"]),
            -int(item["event_count"]),
            str(item["id"]),
        )
    )
    return slices


def group_events_by_user(rows: list[dict[str, Any]]) -> dict[str, dict[str, dict[str, Any]]]:
    grouped: dict[str, dict[str, dict[str, Any]]] = {}
    for row in rows:
        user_id = str(row.get("user_id") or "").strip()
        if not user_id:
            continue
        add_event_to_bucket(grouped.setdefault(user_id, {}), row)
    return grouped


def merge_all_slices(
    grouped: dict[str, dict[str, dict[str, Any]]],
) -> dict[str, dict[str, Any]]:
    merged: dict[str, dict[str, Any]] = {}
    for buckets in grouped.values():
        for key, bucket in buckets.items():
            target = merged.setdefault(
                key,
                empty_slice(
                    provider=str(bucket["provider"]),
                    feature=str(bucket["feature"]),
                    channel=str(bucket["channel"]),
                    event_type=str(bucket["event_type"]),
                ),
            )
            target["event_count"] += int(bucket["event_count"])
            target["unit_count"] += float(bucket["unit_count"])
            target["duration_ms"] += int(bucket["duration_ms"])
            target["estimated_cost_cents"] += float(bucket["estimated_cost_cents"])
    return merged


def largest_driver(slices: list[dict[str, Any]]) -> dict[str, Any] | None:
    metered = [item for item in slices if float(item.get("estimated_cost_cents") or 0) > 0]
    if not metered:
        return None
    top = metered[0]
    return {
        "label_key": top["label_key"],
        "provider": top["provider"],
        "feature": top["feature"],
        "channel": top["channel"],
        "event_type": top["event_type"],
        "estimated_cost_cents": top["estimated_cost_cents"],
        "share": top["share"],
    }


def voice_cost_cents(slices: list[dict[str, Any]]) -> float:
    total = 0.0
    for item in slices:
        channel = str(item.get("channel") or "")
        event_type = str(item.get("event_type") or "")
        if channel == "voice" or event_type in {"stt", "tts", "voice_session"}:
            total += float(item.get("estimated_cost_cents") or 0)
    return total


def pricing_from_cogs(
    *,
    cogs_cents: float,
    active_user_count: int,
    voice_seconds: float,
    voice_cost_cents: float,
) -> dict[str, Any]:
    active = max(int(active_user_count), 0)
    minutes = max(float(voice_seconds), 0.0) / 60.0
    per_user = (cogs_cents / active) if active else 0.0
    per_minute = (voice_cost_cents / minutes) if minutes > 0 else 0.0
    return {
        "cogs_cents": round(cogs_cents, 4),
        "active_user_count": active,
        "voice_minutes": round(minutes, 4),
        "cost_per_active_user_cents": round(per_user, 4),
        "cost_per_voice_minute_cents": round(per_minute, 4),
        "price_floor_2x_cents": round(cogs_cents * 2, 4),
        "price_floor_3x_cents": round(cogs_cents * 3, 4),
        "price_per_user_2x_cents": round(per_user * 2, 4),
        "price_per_user_3x_cents": round(per_user * 3, 4),
        "plaid_included": False,
    }


def attach_user_cost_insights(
    users: list[dict[str, Any]],
    *,
    grouped: dict[str, dict[str, dict[str, Any]]],
    plaid_counts: dict[str, dict[str, int]],
) -> list[dict[str, Any]]:
    enriched: list[dict[str, Any]] = []
    for user in users:
        row = dict(user)
        user_id = str(row.get("user_id") or "")
        slices = finalize_slices(grouped.get(user_id, {}))
        row["cost_breakdown"] = slices
        row["largest_cost_driver"] = largest_driver(slices)
        plaid = plaid_counts.get(user_id, {})
        row["plaid_item_count"] = int(plaid.get("item_count") or 0)
        row["plaid_account_count"] = int(plaid.get("account_count") or 0)
        row["plaid_cost_metered"] = False
        enriched.append(row)
    return enriched


def count_plaid_links(
    items: list[dict[str, Any]],
    accounts: list[dict[str, Any]],
) -> dict[str, dict[str, int]]:
    counts: dict[str, dict[str, int]] = {}
    for row in items:
        user_id = str(row.get("user_id") or "").strip()
        if not user_id:
            continue
        counts.setdefault(user_id, {"item_count": 0, "account_count": 0})
        counts[user_id]["item_count"] += 1
    for row in accounts:
        user_id = str(row.get("user_id") or "").strip()
        if not user_id:
            continue
        counts.setdefault(user_id, {"item_count": 0, "account_count": 0})
        counts[user_id]["account_count"] += 1
    return counts


def plaid_platform_totals(plaid_counts: dict[str, dict[str, int]]) -> dict[str, Any]:
    users_with_plaid = 0
    items = 0
    accounts = 0
    for row in plaid_counts.values():
        item_count = int(row.get("item_count") or 0)
        account_count = int(row.get("account_count") or 0)
        if item_count or account_count:
            users_with_plaid += 1
        items += item_count
        accounts += account_count
    return {
        "metered": False,
        "user_count": users_with_plaid,
        "item_count": items,
        "account_count": accounts,
    }


def _text(value: Any, fallback: str) -> str:
    if isinstance(value, str) and value.strip():
        return value.strip()
    return fallback


def _float(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    return 0.0

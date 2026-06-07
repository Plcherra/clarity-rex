from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Literal


UsageStatus = Literal["success", "failure", "partial", "started", "completed"]

ALLOWED_EVENT_TYPES = frozenset(
    {
        "llm",
        "stt",
        "tts",
        "voice_session",
    }
)

ALLOWED_SURFACES = frozenset(
    {
        "accounts",
        "assistant",
        "background",
        "budgets",
        "chat",
        "dashboard",
        "goals",
        "memory",
        "plaid",
        "profile",
        "transactions",
        "voice",
    }
)

ALLOWED_CHANNELS = frozenset({"api", "background", "chat", "mobile", "voice"})

ALLOWED_STATUSES = frozenset(
    {"success", "failure", "partial", "started", "completed"}
)

class UsageTrackingValidationError(ValueError):
    pass


@dataclass(frozen=True)
class UsageTrackingEvent:
    user_id: str
    event_type: str
    surface: str | None = None
    feature: str | None = None
    channel: str | None = None
    provider: str = "clarity_api"
    model: str = "none"
    duration_ms: int | None = None
    latency_ms: int | None = None
    status: UsageStatus = "success"
    error_class: str | None = None

    def to_insert_payload(self) -> dict[str, Any]:
        _require_non_empty("user_id", self.user_id)
        _require_allowed("event_type", self.event_type, ALLOWED_EVENT_TYPES)
        surface = self.surface or _compat_surface(self.event_type)
        feature = self.feature or _compat_feature(self.event_type)
        channel = self.channel or _compat_channel(self.event_type)
        _require_allowed("surface", surface, ALLOWED_SURFACES)
        _require_allowed("channel", channel, ALLOWED_CHANNELS)
        _require_allowed("status", self.status, ALLOWED_STATUSES)
        _require_non_empty("feature", feature)

        return {
            "user_id": self.user_id,
            "event_type": self.event_type,
            "surface": surface,
            "feature": feature,
            "channel": channel,
            "provider": self.provider or "clarity_api",
            "model": self.model or "none",
            "duration_ms": self.duration_ms,
            "latency_ms": self.latency_ms,
            "status": self.status,
            "error_class": self.error_class,
        }


def _compat_surface(event_type: str) -> str:
    if event_type == "llm":
        return "assistant"
    return "voice"


def _compat_feature(event_type: str) -> str:
    if event_type == "llm":
        return "assistant_response"
    if event_type == "stt":
        return "speech_to_text"
    if event_type == "tts":
        return "text_to_speech"
    return "voice_call"


def _compat_channel(event_type: str) -> str:
    return "voice" if event_type in {"stt", "tts", "voice_session"} else "chat"


def _require_non_empty(name: str, value: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise UsageTrackingValidationError(f'Usage field "{name}" is required.')


def _require_allowed(name: str, value: str, allowed: frozenset[str]) -> None:
    _require_non_empty(name, value)
    if value not in allowed:
        raise UsageTrackingValidationError(f'Usage field "{name}" is not allowed.')

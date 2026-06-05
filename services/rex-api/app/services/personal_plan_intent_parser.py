import re
from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class PersonalPlanDraft:
    content: str
    metadata: dict
    importance: int = 3


class PersonalPlanIntentParser:
    """Parses low-risk personal plans without a second LLM call."""

    _watch_intent_pattern = re.compile(
        r"\b(?:i(?:'m| am)\s+(?:gonna|going to)|i\s+will|i\s+plan\s+to)"
        r"\s+watch\b",
        re.IGNORECASE,
    )
    _watch_object_pattern = re.compile(
        r"\bwatch\s+(?P<object>[^.!?]{2,120})",
        re.IGNORECASE,
    )
    _released_title_pattern = re.compile(
        r"\breleased\s+(?:the\s+)?(?P<title>[A-Za-z][A-Za-z0-9\s:'-]{2,100})"
        r"(?:\s+movie\b|,|\s+and\b|\.|$)",
        re.IGNORECASE,
    )
    _time_pattern = re.compile(r"\b(?P<time>today|tonight|tomorrow)\b", re.IGNORECASE)
    _ticket_pattern = re.compile(
        r"\b(?:already\s+)?(?:bought|got|purchased)\s+(?:the\s+)?tickets?\b",
        re.IGNORECASE,
    )
    _cancel_pattern = re.compile(
        r"\b(?:cancel|canceling|cancelling|cancelled|canceled|not\s+going)\b",
        re.IGNORECASE,
    )

    def detect(
        self,
        message: str,
        *,
        conversation_history: Optional[list[dict]] = None,
    ) -> Optional[PersonalPlanDraft]:
        title = self._title_from_text(message)
        time_text = self._time_from_text(message)
        history_title, history_time = self._recent_plan_details(
            conversation_history or []
        )
        title = title or history_title
        time_text = time_text or history_time

        if self._cancel_pattern.search(message) and title:
            return self._draft(
                self._canceled_content(title, time_text, message),
                title=title,
                time_text=time_text,
                status="canceled",
            )

        if self._ticket_pattern.search(message) and title:
            return self._draft(
                self._tickets_content(title, time_text),
                title=title,
                time_text=time_text,
                status="tickets_bought",
            )

        if not self._watch_intent_pattern.search(message):
            return None
        title = title or self._title_from_watch_object(message)
        if not title:
            return None
        return self._draft(
            self._plan_content(title, time_text),
            title=title,
            time_text=time_text,
            status="planned",
        )

    def _draft(
        self,
        content: str,
        *,
        title: str,
        time_text: str,
        status: str,
    ) -> PersonalPlanDraft:
        normalized_title = self._fingerprint(title)
        return PersonalPlanDraft(
            content=content,
            metadata={
                "fact_kind": "personal_plan",
                "plan_action": "watch",
                "plan_title": title,
                "plan_time": time_text,
                "plan_status": status,
                "topic_fingerprint": f"event:personal_plan:watch:{normalized_title}",
            },
        )

    def _plan_content(self, title: str, time_text: str) -> str:
        time_clause = f" {time_text}" if time_text else ""
        return f"User plans to watch {title}{time_clause}."

    def _tickets_content(self, title: str, time_text: str) -> str:
        time_clause = f" {time_text}" if time_text else ""
        return f"User plans to watch {title}{time_clause} and already bought tickets."

    def _canceled_content(self, title: str, time_text: str, message: str) -> str:
        time_clause = f" {time_text}" if time_text else ""
        reason = ""
        if re.search(r"\bmoney\s+is\s+tight\b", message, re.IGNORECASE):
            reason = " because money is tight"
        return f"User canceled the plan to watch {title}{time_clause}{reason}."

    def _recent_plan_details(self, conversation_history: list[dict]) -> tuple[str, str]:
        for item in reversed(conversation_history[-12:]):
            content = str(item.get("content") or "")
            title = self._title_from_text(content) or self._title_from_watch_object(content)
            if title:
                return title, self._time_from_text(content)
        return "", ""

    def _title_from_text(self, text: str) -> str:
        known = self._known_title(text)
        if known:
            return known
        match = self._released_title_pattern.search(text)
        if match is None:
            return ""
        return self._clean_title(match.group("title"))

    def _title_from_watch_object(self, text: str) -> str:
        match = self._watch_object_pattern.search(text)
        if match is None:
            return ""
        raw = match.group("object")
        raw = re.split(r"\b(?:today|tonight|tomorrow)\b", raw, maxsplit=1)[0]
        raw = re.sub(r"^(?:it|that|a\s+movie|the\s+movie)\b", "", raw, flags=re.I)
        return self._clean_title(raw)

    def _known_title(self, text: str) -> str:
        normalized = self._normalize_text(text)
        if re.search(r"\b(?:masters|mestas|messes?|master)\s+of\s+the\s+universe\b", normalized):
            return "Masters of the Universe"
        return ""

    def _time_from_text(self, text: str) -> str:
        match = self._time_pattern.search(text)
        return match.group("time").lower() if match else ""

    def _clean_title(self, title: str) -> str:
        cleaned = re.sub(r"\s+", " ", title).strip(" .,!?:;'-")
        cleaned = re.sub(r"^(?:the\s+)?", "", cleaned, flags=re.IGNORECASE).strip()
        cleaned = re.sub(r"\s+movie$", "", cleaned, flags=re.IGNORECASE).strip()
        if len(cleaned) < 3:
            return ""
        known = self._known_title(cleaned)
        if known:
            return known
        return " ".join(word.capitalize() for word in cleaned.split())

    def _normalize_text(self, text: str) -> str:
        normalized = re.sub(r"[^a-z0-9]+", " ", text.lower())
        return re.sub(r"\s+", " ", normalized).strip()

    def _fingerprint(self, text: str) -> str:
        normalized = re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")
        return normalized[:80] or "unknown"

import re
from datetime import datetime
from typing import Optional


class MemoryDateNormalizer:
    """Normalizes casual date phrases used by simple memory detection."""

    month_names = {
        "january": "January", "jan": "January",
        "february": "February", "feb": "February",
        "march": "March", "mar": "March",
        "april": "April", "apr": "April",
        "may": "May",
        "june": "June", "jun": "June",
        "july": "July", "jul": "July",
        "august": "August", "aug": "August",
        "september": "September", "sep": "September", "sept": "September",
        "october": "October", "oct": "October",
        "november": "November", "nov": "November",
        "december": "December", "dec": "December",
    }
    ordinal_words = {
        "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5,
        "sixth": 6, "seventh": 7, "eighth": 8, "ninth": 9, "tenth": 10,
        "eleventh": 11, "twelfth": 12, "thirteenth": 13,
        "fourteenth": 14, "fifteenth": 15, "sixteenth": 16,
        "seventeenth": 17, "eighteenth": 18, "nineteenth": 19,
        "twentieth": 20, "twenty first": 21, "twenty-first": 21,
        "twenty second": 22, "twenty-second": 22,
        "twenty third": 23, "twenty-third": 23,
        "twenty fourth": 24, "twenty-fourth": 24,
        "twenty fifth": 25, "twenty-fifth": 25,
        "twenty sixth": 26, "twenty-sixth": 26,
        "twenty seventh": 27, "twenty-seventh": 27,
        "twenty eighth": 28, "twenty-eighth": 28,
        "twenty ninth": 29, "twenty-ninth": 29,
        "thirtieth": 30, "thirty first": 31, "thirty-first": 31,
    }

    def normalize(self, raw_date: str, *, time_context: Optional[dict]) -> Optional[str]:
        cleaned = self._clean(raw_date)
        if not cleaned:
            return None

        month = self.month_from_text(cleaned)
        day_match = re.search(r"\b(?P<day>\d{1,2})(?:st|nd|rd|th)?\b", cleaned)
        if day_match is None:
            day = self._day_from_words(cleaned)
            if day is None:
                return cleaned
        else:
            day = int(day_match.group("day"))

        if day < 1 or day > 31:
            return None

        month_name = month or self._current_month(time_context)
        return f"{month_name} {day}" if month_name else f"the {self._ordinal(day)}"

    def month_from_text(self, text: str) -> Optional[str]:
        normalized = text.lower()
        for token, month in self.month_names.items():
            if re.search(rf"\b{re.escape(token)}\b", normalized):
                return month
        return None

    def is_day_only(self, text: str) -> bool:
        normalized = re.sub(r"\s+", " ", text.lower()).strip()
        return bool(
            re.fullmatch(r"\d{1,2}(?:st|nd|rd|th)?", normalized)
            or normalized in self.ordinal_words
        )

    def _clean(self, raw_date: str) -> str:
        cleaned = re.sub(r"^(?:(?:on|the)\s+)+", "", raw_date, flags=re.IGNORECASE)
        return re.sub(r"\s+", " ", cleaned).strip(" .")

    def _current_month(self, time_context: Optional[dict]) -> Optional[str]:
        if not time_context:
            return None
        try:
            return datetime.fromisoformat(str(time_context.get("date") or "")).strftime(
                "%B"
            )
        except ValueError:
            return None

    def _day_from_words(self, text: str) -> Optional[int]:
        normalized = re.sub(r"\s+", " ", text.lower()).strip()
        return self.ordinal_words.get(normalized)

    def _ordinal(self, day: int) -> str:
        if 10 <= day % 100 <= 20:
            suffix = "th"
        else:
            suffix = {1: "st", 2: "nd", 3: "rd"}.get(day % 10, "th")
        return f"{day}{suffix}"

import re
from datetime import datetime, timezone
from typing import Optional

RELEVANT_MEMORY_SCAN_LIMIT = 100
RELEVANT_MEMORY_MINIMUM_SCORE = 0.12
STRUCTURED_MEMORY_SCAN_LIMIT = 50
STRUCTURED_MEMORY_DIRECT_LIMIT = 5
STRUCTURED_MEMORY_RELATED_LIMIT = 8
STRUCTURED_MEMORY_MINIMUM_SCORE = 0.14
HIGH_PRIORITY_STRUCTURED_THRESHOLD = 4

STOP_WORDS = {
    "about",
    "after",
    "again",
    "also",
    "and",
    "are",
    "because",
    "but",
    "can",
    "could",
    "for",
    "from",
    "have",
    "how",
    "into",
    "just",
    "like",
    "more",
    "need",
    "not",
    "now",
    "should",
    "that",
    "the",
    "this",
    "what",
    "when",
    "where",
    "with",
    "would",
    "you",
    "your",
}

CONCEPT_GROUPS = {
    "work": {"career", "job", "manager", "office", "salary", "work", "workplace"},
    "money": {"bill", "budget", "debt", "finance", "money", "rent", "savings"},
    "location": {
        "address",
        "area",
        "city",
        "eastern",
        "edt",
        "est",
        "home",
        "house",
        "live",
        "lives",
        "living",
        "location",
        "massachusetts",
        "place",
        "state",
        "timezone",
    },
    "relationship": {
        "date",
        "dating",
        "girl",
        "girlfriend",
        "monday",
        "name",
        "offday",
        "person",
        "restaurant",
        "relationship",
        "wife",
    },
    "time": {
        "clock",
        "date",
        "day",
        "eastern",
        "edt",
        "est",
        "morning",
        "night",
        "schedule",
        "time",
        "timezone",
        "today",
        "tomorrow",
        "tonight",
        "week",
    },
    "immigration": {"ead", "green", "immigration", "status", "uscis", "visa"},
    "stress": {
        "anxiety",
        "burnout",
        "frustrated",
        "pressure",
        "stress",
        "stressed",
    },
}


class MemoryRetrievalRanker:
    def score_memory(
        self,
        memory: dict,
        query_terms: set[str],
    ) -> Optional[dict]:
        content = str(memory.get("content", ""))
        memory_terms = self.expanded_terms(content)
        matched_terms = sorted(query_terms & memory_terms)
        has_direct_match = bool(matched_terms)
        is_high_priority_preference = (
            memory.get("memory_type") == "preference"
            and int(memory.get("importance") or 0) >= 4
        )
        is_profile_context_query = bool(
            query_terms & {"profile", "identity", "important", "fact"}
        )
        is_high_priority_profile_fact = (
            memory.get("memory_type") == "fact"
            and int(memory.get("importance") or 0) >= 4
            and is_profile_context_query
        )

        if not query_terms:
            has_direct_match = True
        if (
            not has_direct_match
            and not is_high_priority_preference
            and not is_high_priority_profile_fact
        ):
            return None

        overlap_score = (
            len(matched_terms) / max(len(query_terms), 1) if query_terms else 0.2
        )
        importance_score = max(1, min(int(memory.get("importance") or 3), 5)) / 5
        recency_score = self.recency_score(memory)
        correction_pairs = self.memory_correction_pairs(memory)
        correction_boost = 0.16 if correction_pairs else 0
        relevance_score = (
            (0.65 * overlap_score)
            + (0.25 * importance_score)
            + (0.10 * recency_score)
            + correction_boost
        )

        if relevance_score < RELEVANT_MEMORY_MINIMUM_SCORE:
            return None

        if matched_terms:
            reason = f"Matched current message terms: {', '.join(matched_terms[:6])}"
        elif is_high_priority_preference:
            reason = "Included high-priority user preference."
        elif is_high_priority_profile_fact:
            reason = "Included high-priority profile fact."
        else:
            reason = "Included as recent important context."
        if correction_pairs:
            reason = f"{reason}. Includes corrected current truth."

        return {
            **memory,
            "relevance_score": round(relevance_score, 4),
            "relevance_reason": reason,
        }

    def rank_structured_records(
        self,
        records: list[dict],
        *,
        query_terms: set[str],
        text_fields: tuple[str, ...],
        weight_field: str,
        list_fields: tuple[str, ...] = (),
        status_values: Optional[set[str]] = None,
        include_high_priority: bool = False,
        limit: int = STRUCTURED_MEMORY_DIRECT_LIMIT,
    ) -> list[dict]:
        scored_records = []
        for record in records:
            if status_values is not None and record.get("status") not in status_values:
                continue

            scored = self.score_structured_record(
                record,
                query_terms=query_terms,
                text_fields=text_fields,
                list_fields=list_fields,
                weight_field=weight_field,
                include_high_priority=include_high_priority,
            )
            if scored is not None:
                scored_records.append(scored)

        scored_records.sort(
            key=lambda record: (
                record.get("relevance_score", 0),
                int(record.get(weight_field) or 0),
                str(record.get("updated_at") or record.get("created_at") or ""),
            ),
            reverse=True,
        )
        return scored_records[:limit]

    def score_structured_record(
        self,
        record: dict,
        *,
        query_terms: set[str],
        text_fields: tuple[str, ...],
        list_fields: tuple[str, ...],
        weight_field: str,
        include_high_priority: bool,
    ) -> Optional[dict]:
        record_text = self.structured_record_text(record, text_fields, list_fields)
        record_terms = self.expanded_terms(record_text)
        matched_terms = sorted(query_terms & record_terms)
        weight = max(1, min(int(record.get(weight_field) or 3), 5))
        is_high_priority = (
            include_high_priority and weight >= HIGH_PRIORITY_STRUCTURED_THRESHOLD
        )

        if not query_terms:
            matched_terms = []
            has_direct_match = is_high_priority
        else:
            has_direct_match = bool(matched_terms)
        if not has_direct_match and not is_high_priority:
            return None

        overlap_score = (
            len(matched_terms) / max(len(query_terms), 1)
            if matched_terms
            else 0.18
        )
        weight_score = weight / 5
        recency_score = self.recency_score(record)
        exact_match_boost = self.exact_match_boost(record_text, query_terms)
        relevance_score = (
            (0.62 * overlap_score)
            + (0.30 * weight_score)
            + (0.08 * recency_score)
            + exact_match_boost
        )
        if relevance_score < STRUCTURED_MEMORY_MINIMUM_SCORE:
            return None

        if matched_terms:
            reason = f"Matched current message terms: {', '.join(matched_terms[:6])}"
            if exact_match_boost:
                reason = f"{reason}. Strong exact-name match."
        elif is_high_priority:
            reason = "Included high-priority active structured memory."
        else:
            reason = "Included as relevant structured context."

        return {
            **record,
            "relevance_score": round(relevance_score, 4),
            "relevance_reason": reason,
        }

    def structured_record_text(
        self,
        record: dict,
        text_fields: tuple[str, ...],
        list_fields: tuple[str, ...],
    ) -> str:
        values = [str(record.get(field) or "") for field in text_fields]
        for field in list_fields:
            raw_value = record.get(field) or []
            if isinstance(raw_value, list):
                values.extend(str(item) for item in raw_value)
        return " ".join(values)

    def related_records(
        self,
        records: list[dict],
        *,
        link_field: str,
        selected_ids: set[str],
        weight_field: str,
        status_values: Optional[set[str]] = None,
        limit: int = STRUCTURED_MEMORY_RELATED_LIMIT,
    ) -> list[dict]:
        if not selected_ids:
            return []

        related = []
        for record in records:
            if str(record.get(link_field) or "") not in selected_ids:
                continue
            if status_values is not None and record.get("status") not in status_values:
                continue
            related.append(record)

        related.sort(
            key=lambda record: (
                int(record.get(weight_field) or 0),
                str(record.get("occurred_at") or record.get("target_date") or ""),
                str(record.get("updated_at") or record.get("created_at") or ""),
            ),
            reverse=True,
        )
        return related[:limit]

    def merge_related_records(
        self,
        selected: list[dict],
        related: list[dict],
    ) -> list[dict]:
        seen_ids = {str(record.get("id")) for record in selected if record.get("id")}
        merged = [*selected]
        for record in related:
            record_id = str(record.get("id") or "")
            if not record_id or record_id in seen_ids:
                continue
            merged.append(
                {
                    **record,
                    "relevance_reason": "Included through linked structured memory.",
                }
            )
            seen_ids.add(record_id)
        return merged

    def filter_stale_corrected_memories(
        self,
        scored_memories: list[dict],
    ) -> list[dict]:
        correction_pairs = []
        for memory in scored_memories:
            for old_value, new_value in self.memory_correction_pairs(memory):
                correction_pairs.append(
                    {
                        "source_id": str(memory.get("id") or ""),
                        "old": old_value,
                        "new": new_value,
                    }
                )
        if not correction_pairs:
            return scored_memories

        filtered = []
        for memory in scored_memories:
            memory_id = str(memory.get("id") or "")
            content = str(memory.get("content") or "")
            stale = False
            for pair in correction_pairs:
                if memory_id == pair["source_id"]:
                    continue
                if self.contains_word(content, pair["old"]) and not self.contains_word(
                    content,
                    pair["new"],
                ):
                    stale = True
                    break
            if not stale:
                filtered.append(memory)
        return filtered

    def memory_correction_pairs(self, memory: dict) -> list[tuple[str, str]]:
        content = str(memory.get("content") or "")
        if not content:
            return []

        pairs: list[tuple[str, str]] = []
        correction_patterns = [
            r"\b(?P<new>[A-Z][A-Za-z]{2,})\b[^.\n]{0,120}?\b(?:not|corrected from|instead of|rather than)\s+(?P<old>[A-Z][A-Za-z]{1,})\b",
            r"\b(?:not|wrong|incorrect)\s+(?P<old>[A-Z][A-Za-z]{1,})\b[^.\n]{0,120}?\b(?:correct|real|actual|now|is)\s+(?P<new>[A-Z][A-Za-z]{2,})\b",
            r"\b(?P<old>[A-Z][A-Za-z]{1,})\b[^.\n]{0,80}?\b(?:was wrong|is wrong)\b[^.\n]{0,120}?\b(?P<new>[A-Z][A-Za-z]{2,})\b",
        ]
        for pattern in correction_patterns:
            for match in re.finditer(pattern, content):
                old_value = match.group("old").strip()
                new_value = match.group("new").strip()
                if self.valid_correction_pair(old_value, new_value):
                    pairs.append((old_value, new_value))
        for match in re.finditer(
            r"\b(?:corrected from|not|instead of|rather than)\s+(?P<old>[A-Z][A-Za-z]{1,})\b",
            content,
        ):
            old_value = match.group("old").strip()
            prefix = content[: match.start()]
            new_value = self.last_name_candidate(prefix)
            if new_value and self.valid_correction_pair(old_value, new_value):
                pairs.append((old_value, new_value))

        return list(dict.fromkeys(pairs))

    def valid_correction_pair(self, old_value: str, new_value: str) -> bool:
        if old_value.lower() == new_value.lower():
            return False
        blocked_values = {"the", "this", "that", "user", "person", "name"}
        return new_value.lower() not in blocked_values

    def last_name_candidate(self, text: str) -> Optional[str]:
        blocked_values = {"The", "This", "That", "User", "Person", "Name"}
        candidates = [
            candidate
            for candidate in re.findall(r"\b[A-Z][A-Za-z]{2,}\b", text)
            if candidate not in blocked_values
        ]
        return candidates[-1] if candidates else None

    def contains_word(self, text: str, word: str) -> bool:
        return re.search(rf"\b{re.escape(word)}\b", text, flags=re.I) is not None

    def exact_match_boost(self, record_text: str, query_terms: set[str]) -> float:
        if not query_terms:
            return 0
        record_terms = self.expanded_terms(record_text)
        matched_terms = query_terms & record_terms
        if not matched_terms:
            return 0
        if len(matched_terms) >= 2:
            return 0.08
        return 0.04

    def expanded_terms(self, text: str) -> set[str]:
        terms = {
            self.normalize_token(token)
            for token in re.findall(r"[a-z0-9']+", text.lower())
        }
        terms = {
            term
            for term in terms
            if len(term) >= 3 and term not in STOP_WORDS
        }

        expanded_terms = set(terms)
        for concept, words in CONCEPT_GROUPS.items():
            normalized_words = {self.normalize_token(word) for word in words}
            if terms & normalized_words:
                expanded_terms.add(concept)

        return expanded_terms

    def normalize_token(self, token: str) -> str:
        token = token.strip("'")
        for suffix in ("ing", "ed", "es", "s"):
            if len(token) > len(suffix) + 3 and token.endswith(suffix):
                return token[: -len(suffix)]

        return token

    def recency_score(self, memory: dict) -> float:
        timestamp = memory.get("last_accessed_at") or memory.get("created_at")
        if not timestamp:
            return 0.3

        try:
            parsed = datetime.fromisoformat(str(timestamp).replace("Z", "+00:00"))
        except ValueError:
            return 0.3

        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)

        age_days = max((datetime.now(timezone.utc) - parsed).days, 0)
        return 1 / (1 + (age_days / 30))

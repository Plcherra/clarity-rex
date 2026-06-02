import json
import re
from typing import Any, Optional

VALID_MEMORY_TYPES = {"fact", "preference", "event"}
VALID_STRUCTURED_SECTIONS = {
    "entities",
    "entity_events",
    "personal_rules",
    "plans",
    "plan_milestones",
    "commitments",
}
MIN_IMPORTANCE_TO_SAVE = 3


def looks_noisy(content: str) -> bool:
    lowered = content.lower()
    noisy_phrases = (
        "the user asked",
        "the user wants an answer",
        "assistant should",
        "rex should",
        "current question",
        "this conversation",
    )
    return any(phrase in lowered for phrase in noisy_phrases)


class MemoryExtractionParser:
    def turn_payload(self, user_message: dict, assistant_message: dict) -> str:
        return json.dumps(
            {
                "user_message": str(user_message.get("content", "")),
                "assistant_response_context_only": str(
                    assistant_message.get("content", "")
                ),
            },
            ensure_ascii=True,
        )

    def parse_candidates(self, raw_response: str) -> list[dict]:
        return self.parse_extraction_payload(raw_response)["memories"]

    def parse_extraction_payload(self, raw_response: str) -> dict[str, Any]:
        try:
            payload = self.extract_json_payload(raw_response)
            data = json.loads(payload)
        except (TypeError, json.JSONDecodeError):
            return {"memories": [], "structured_memories": {}}

        if isinstance(data, list):
            candidates = data
            structured_memories = {}
        elif isinstance(data, dict):
            candidates = data.get("memories", [])
            structured_memories = data.get("structured_memories", {})
        else:
            return {"memories": [], "structured_memories": {}}

        if not isinstance(structured_memories, dict):
            structured_memories = {}

        normalized_structured = {
            section: [
                candidate
                for candidate in structured_memories.get(section, [])
                if isinstance(candidate, dict)
            ]
            for section in VALID_STRUCTURED_SECTIONS
            if isinstance(structured_memories.get(section, []), list)
        }

        return {
            "memories": [
                candidate
                for candidate in candidates
                if isinstance(candidate, dict)
            ],
            "structured_memories": normalized_structured,
        }

    def extract_json_payload(self, raw_response: str) -> str:
        text = raw_response.strip()
        fenced_match = re.search(r"```(?:json)?\s*(.*?)```", text, flags=re.S | re.I)
        if fenced_match:
            return fenced_match.group(1).strip()

        object_start = text.find("{")
        object_end = text.rfind("}")
        list_start = text.find("[")
        list_end = text.rfind("]")

        if list_start != -1 and (
            object_start == -1 or list_start < object_start
        ) and list_end > list_start:
            return text[list_start : list_end + 1]
        if object_start != -1 and object_end > object_start:
            return text[object_start : object_end + 1]
        if list_start != -1 and list_end > list_start:
            return text[list_start : list_end + 1]

        return text

    def normalize_candidate(self, candidate: dict) -> Optional[dict]:
        memory_type = str(candidate.get("memory_type", "")).strip().lower()
        content = " ".join(str(candidate.get("content", "")).split())
        rationale = " ".join(str(candidate.get("rationale", "")).split())

        try:
            importance = int(candidate.get("importance", 0))
        except (TypeError, ValueError):
            return None

        if memory_type not in VALID_MEMORY_TYPES:
            return None
        if importance < MIN_IMPORTANCE_TO_SAVE or importance > 5:
            return None
        if len(content) < 8 or looks_noisy(content):
            return None

        return {
            "memory_type": memory_type,
            "content": content,
            "importance": importance,
            "rationale": rationale or "Useful future context.",
        }

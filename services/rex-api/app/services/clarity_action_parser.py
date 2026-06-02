import json
import re
from typing import Optional


CLARITY_ACTION_BLOCK_PATTERN = re.compile(
    r"```clarity_action\s*(.*?)```",
    re.IGNORECASE | re.DOTALL,
)


class ClarityActionParser:
    def extract_proposals(self, response: str) -> tuple[str, list[dict]]:
        proposals: list[dict] = []

        def replace_block(match: re.Match[str]) -> str:
            raw_json = match.group(1).strip()
            try:
                decoded = json.loads(raw_json)
            except json.JSONDecodeError:
                return ""

            items = decoded if isinstance(decoded, list) else [decoded]
            for item in items:
                if isinstance(item, dict):
                    proposal = self.normalize_proposal(
                        item,
                        index=len(proposals) + 1,
                    )
                    if proposal is not None:
                        proposals.append(proposal)
            return ""

        cleaned = CLARITY_ACTION_BLOCK_PATTERN.sub(replace_block, response)
        return cleaned.strip(), proposals

    def normalize_proposal(
        self,
        proposal: dict,
        *,
        index: int,
    ) -> Optional[dict]:
        action = str(proposal.get("action") or "").strip()
        payload = proposal.get("payload")
        if not action or not isinstance(payload, dict):
            return None

        confirmation_text = str(
            proposal.get("confirmation_text")
            or proposal.get("summary")
            or f"Confirm {action.replace('_', ' ')}?"
        ).strip()
        risk_level = str(proposal.get("risk_level") or "medium").strip().lower()
        if risk_level not in {"low", "medium", "high"}:
            risk_level = "medium"

        return {
            "id": str(proposal.get("id") or f"clarity-action-{index}"),
            "action": action,
            "payload": payload,
            "confirmation_text": confirmation_text,
            "risk_level": risk_level,
            "status": "pending",
        }

    def with_memory_changes(
        self,
        memory_changes: Optional[dict],
        clarity_action_proposals: list[dict],
    ) -> Optional[dict]:
        if not clarity_action_proposals:
            return memory_changes

        merged = dict(memory_changes or {})
        merged["clarity_action_proposals"] = clarity_action_proposals
        return merged


class ClarityActionStreamFilter:
    marker = "```clarity_action"
    end_marker = "```"

    def __init__(self) -> None:
        self._buffer = ""
        self._inside_action_block = False

    def feed(self, token: str) -> list[str]:
        self._buffer += token
        visible: list[str] = []

        while self._buffer:
            if self._inside_action_block:
                end_index = self._buffer.find(self.end_marker)
                if end_index == -1:
                    keep = self._suffix_prefix_length(self._buffer, self.end_marker)
                    self._buffer = self._buffer[-keep:] if keep else ""
                    break
                self._buffer = self._buffer[end_index + len(self.end_marker) :]
                self._inside_action_block = False
                continue

            marker_index = self._buffer.lower().find(self.marker)
            if marker_index >= 0:
                if marker_index > 0:
                    visible.append(self._buffer[:marker_index])
                self._buffer = self._buffer[marker_index + len(self.marker) :]
                self._inside_action_block = True
                continue

            keep = self._suffix_prefix_length(self._buffer.lower(), self.marker)
            emit_length = len(self._buffer) - keep
            if emit_length > 0:
                visible.append(self._buffer[:emit_length])
                self._buffer = self._buffer[emit_length:]
            break

        return visible

    def finish(self) -> list[str]:
        if self._inside_action_block:
            self._buffer = ""
            return []
        if not self._buffer:
            return []
        visible = [self._buffer]
        self._buffer = ""
        return visible

    def _suffix_prefix_length(self, value: str, prefix: str) -> int:
        max_length = min(len(value), len(prefix) - 1)
        for length in range(max_length, 0, -1):
            if prefix.startswith(value[-length:]):
                return length
        return 0

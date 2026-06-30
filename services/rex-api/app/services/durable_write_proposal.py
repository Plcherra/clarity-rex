"""Unified durable write proposals — the user-visible contract before any save."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Literal, Optional

WriteKind = Literal[
    "memory",
    "plan",
    "milestone",
    "commitment",
    "entity_event",
    "entity",
    "rule",
    "update_plan",
    "update_milestone",
    "update_commitment",
    "delete",
]

_LEGACY_ACTION_BY_KIND: dict[str, str] = {
    "memory": "save_memory",
    "plan": "save_plan",
    "milestone": "save_plan_milestone",
    "commitment": "save_commitment",
    "entity_event": "save_entity_event",
    "update_plan": "update_plan",
    "update_milestone": "update_plan_milestone",
    "update_commitment": "update_commitment",
}


@dataclass(frozen=True)
class DurableWriteProposal:
    write_kind: str
    title: str
    body: str
    target_label: Optional[str] = None
    editable_fields: tuple[str, ...] = ("title", "body")
    apply_snapshot: dict[str, Any] = field(default_factory=dict)
    proposal_id: str = "write-1"
    merge_target_title: Optional[str] = None
    risk_level: str = "medium"
    custom_assistant_prompt: Optional[str] = None

    @property
    def legacy_action(self) -> str:
        return _LEGACY_ACTION_BY_KIND.get(self.write_kind, "save_plan")

    def confirmation_text(self) -> str:
        if self.merge_target_title:
            return (
                f"Update existing plan \"{self.merge_target_title}\" with: "
                f"{self.title}?"
            )
        if self.write_kind == "memory":
            return f"Save to Clarity Knows as {self._kind_label()}?\n{self.body}"
        if self.write_kind == "plan":
            return f"Save as a new plan in Goals?\n{self.title}"
        if self.write_kind == "milestone":
            target = self.target_label or "your plan"
            return f"Save as a milestone under {target}?\n{self.title}"
        if self.write_kind == "commitment":
            target = self.target_label or "your plan"
            return f"Save as a commitment under {target}?\n{self.title}"
        if self.write_kind == "update_plan":
            target = self.target_label or "your plan"
            return f"Update plan \"{target}\" with:\n{self.body or self.title}"
        if self.write_kind == "entity_event":
            target = self.target_label or "that person"
            return f"Save as a note on {target}?\n{self.body or self.title}"
        return f"Save this {self._kind_label()}?\n{self.title}"

    def assistant_prompt(self) -> str:
        if self.custom_assistant_prompt:
            return self.custom_assistant_prompt
        text = self.confirmation_text().rstrip("?")
        return f"I can {text[0].lower()}{text[1:]} Should I save that?"

    def _kind_label(self) -> str:
        labels = {
            "memory": "a memory note",
            "plan": "a plan",
            "milestone": "a milestone",
            "commitment": "a commitment",
            "entity_event": "a related note",
            "update_plan": "a plan update",
        }
        return labels.get(self.write_kind, "saved item")

    def to_client_dict(self, *, status: str = "pending") -> dict[str, Any]:
        return {
            "id": self.proposal_id,
            "write_kind": self.write_kind,
            "action": self.legacy_action,
            "title": self.title,
            "body": self.body,
            "target_label": self.target_label,
            "merge_target_title": self.merge_target_title,
            "editable_fields": list(self.editable_fields),
            "payload": {},
            "confirmation_text": self.confirmation_text(),
            "risk_level": self.risk_level,
            "status": status,
        }

    def to_dict(self) -> dict[str, Any]:
        return {
            "write_kind": self.write_kind,
            "title": self.title,
            "body": self.body,
            "target_label": self.target_label,
            "editable_fields": list(self.editable_fields),
            "apply_snapshot": dict(self.apply_snapshot),
            "proposal_id": self.proposal_id,
            "merge_target_title": self.merge_target_title,
            "risk_level": self.risk_level,
            "custom_assistant_prompt": self.custom_assistant_prompt,
        }

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> Optional[DurableWriteProposal]:
        if not isinstance(raw, dict):
            return None
        write_kind = str(raw.get("write_kind") or "").strip()
        title = str(raw.get("title") or "").strip()
        if not write_kind or not title:
            return None
        editable = raw.get("editable_fields") or ("title", "body")
        if isinstance(editable, list):
            editable_fields = tuple(str(item) for item in editable)
        else:
            editable_fields = ("title", "body")
        snapshot = raw.get("apply_snapshot") or {}
        return cls(
            write_kind=write_kind,
            title=title,
            body=str(raw.get("body") or ""),
            target_label=str(raw.get("target_label") or "").strip() or None,
            editable_fields=editable_fields,
            apply_snapshot=dict(snapshot) if isinstance(snapshot, dict) else {},
            proposal_id=str(raw.get("proposal_id") or "write-1"),
            merge_target_title=str(raw.get("merge_target_title") or "").strip() or None,
            risk_level=str(raw.get("risk_level") or "medium"),
            custom_assistant_prompt=str(raw.get("custom_assistant_prompt") or "").strip()
            or None,
        )

    def with_edits(self, edits: Optional[dict[str, Any]]) -> DurableWriteProposal:
        if not edits:
            return self
        title = str(edits.get("title") or self.title).strip() or self.title
        body = str(edits.get("body") if "body" in edits else self.body).strip()
        snapshot = dict(self.apply_snapshot)
        inner = dict(snapshot.get("payload") or {})
        if "title" in edits:
            inner["title"] = title
        if "body" in edits:
            inner["content"] = body
            inner["description"] = body
            inner["commitment_text"] = body
            inner["desired_outcome"] = body
        if inner:
            snapshot["payload"] = inner
        return DurableWriteProposal(
            write_kind=self.write_kind,
            title=title,
            body=body or self.body,
            target_label=self.target_label,
            editable_fields=self.editable_fields,
            apply_snapshot=snapshot,
            proposal_id=self.proposal_id,
            merge_target_title=self.merge_target_title,
            risk_level=self.risk_level,
            custom_assistant_prompt=self.custom_assistant_prompt,
        )

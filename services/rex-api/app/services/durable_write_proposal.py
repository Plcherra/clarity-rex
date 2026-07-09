"""Unified durable write proposals — the user-visible contract before any save."""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from typing import Any, Literal, Optional

WriteKind = Literal[
    "memory",
    "plan",
    "milestone",
    "open_thread",
    "entity_event",
    "entity",
    "rule",
    "update_plan",
    "update_milestone",
    "delete",
]

_LEGACY_ACTION_BY_KIND: dict[str, str] = {
    "memory": "save_memory",
    "plan": "save_plan",
    "milestone": "save_plan_milestone",
    "open_thread": "save_open_thread",
    "entity_event": "save_entity_event",
    "update_plan": "update_plan",
    "update_milestone": "update_plan_milestone",
    "delete": "delete_record",
}


def new_durable_write_proposal_id() -> str:
    return f"write-{uuid.uuid4().hex[:12]}"


@dataclass(frozen=True)
class DurableWriteProposal:
    write_kind: str
    title: str
    body: str
    target_label: Optional[str] = None
    editable_fields: tuple[str, ...] = ("title", "body")
    apply_snapshot: dict[str, Any] = field(default_factory=dict)
    proposal_id: str = field(default_factory=new_durable_write_proposal_id)
    merge_target_title: Optional[str] = None
    risk_level: str = "medium"
    custom_assistant_prompt: Optional[str] = None
    person_card: Optional[dict[str, Any]] = None

    @property
    def legacy_action(self) -> str:
        return _LEGACY_ACTION_BY_KIND.get(self.write_kind, "save_plan")

    def confirmation_text(self) -> str:
        if self.merge_target_title:
            return (
                f"Update existing plan \"{self.merge_target_title}\" with: "
                f"{self.title}?"
            )
        if self.person_card:
            relationship = str(self.person_card.get("relationship") or "").strip()
            name = str(self.person_card.get("display_name") or "").strip() or "this person"
            label = f"your {relationship} ({name})" if relationship else name
            if self.person_card.get("merge_hint"):
                return f"Merge into one person card for {label}?"
            return f"Save person card for {label} to Clarity Knows?"
        if self.write_kind == "memory":
            return f"Save to Clarity Knows as {self._kind_label()}?\n{self.body}"
        if self.write_kind == "plan":
            return f"Save as a new plan in Goals?\n{self.title}"
        if self.write_kind == "milestone":
            target = self.target_label or "your plan"
            return f"Save as a milestone under {target}?\n{self.title}"
        if self.write_kind == "open_thread":
            return (
                "Track as an open thread in Goals?\n"
                f"{self.title}\n"
                "This is companion follow-up — not saved memory."
            )
        if self.write_kind == "update_plan":
            target = self.target_label or "your plan"
            return f"Update plan \"{target}\" with:\n{self.body or self.title}"
        if self.write_kind == "entity_event":
            target = self.target_label or "that person"
            return f"Save as a note on {target}?\n{self.body or self.title}"
        if self.write_kind == "delete":
            return (
                f"Permanently delete this {self._delete_kind_label()}?\n"
                f"{self.title}\n\nThis action cannot be undone."
            )
        return f"Save this {self._kind_label()}?\n{self.title}"

    def assistant_prompt(self) -> str:
        if self.custom_assistant_prompt:
            return self.custom_assistant_prompt
        text = self.confirmation_text().rstrip("?")
        return (
            f"I can {text[0].lower()}{text[1:]}. "
            "Tap confirm to save — nothing is saved until you confirm."
        )

    def text_confirmation_prompt(self) -> str:
        """Chat-only confirmation copy when auto-suggestions are text-only."""
        if self.custom_assistant_prompt:
            base = self.custom_assistant_prompt
            return (
                base.replace(
                    "Tap confirm to save — nothing is saved until you confirm.",
                    "Say yes to save — nothing is saved until you confirm.",
                )
                .replace("Tap confirm", "Say yes")
            )
        text = self.confirmation_text().rstrip("?")
        return (
            f"I can {text[0].lower()}{text[1:]}. "
            "Say yes to save — nothing is saved until you confirm."
        )

    def _kind_label(self) -> str:
        labels = {
            "memory": "a memory note",
            "plan": "a plan",
            "milestone": "a milestone",
            "open_thread": "an open thread",
            "entity_event": "a related note",
            "update_plan": "a plan update",
            "delete": "saved item",
        }
        return labels.get(self.write_kind, "saved item")

    def _delete_kind_label(self) -> str:
        table = str((self.apply_snapshot.get("payload") or {}).get("table") or "")
        labels = {
            "long_term_memory": "memory note",
            "entities": "person or place card",
            "entity_events": "related note",
            "personal_rules": "rule",
            "plans": "goal",
            "plan_milestones": "milestone",
            "open_threads": "open thread",
        }
        return labels.get(table, "saved item")

    def to_client_dict(self, *, status: str = "pending") -> dict[str, Any]:
        payload = dict((self.apply_snapshot.get("payload") or {}))
        client = {
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
        if self.write_kind == "delete":
            client["delete_table"] = payload.get("table")
        if self.person_card:
            client["person_card"] = dict(self.person_card)
        return client

    def to_dict(self) -> dict[str, Any]:
        payload = {
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
        if self.person_card:
            payload["person_card"] = dict(self.person_card)
        return payload

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
        person_card = raw.get("person_card")
        return cls(
            write_kind=write_kind,
            title=title,
            body=str(raw.get("body") or ""),
            target_label=str(raw.get("target_label") or "").strip() or None,
            editable_fields=editable_fields,
            apply_snapshot=dict(snapshot) if isinstance(snapshot, dict) else {},
            proposal_id=str(raw.get("proposal_id") or raw.get("id") or new_durable_write_proposal_id()),
            merge_target_title=str(raw.get("merge_target_title") or "").strip() or None,
            risk_level=str(raw.get("risk_level") or "medium"),
            custom_assistant_prompt=str(raw.get("custom_assistant_prompt") or "").strip()
            or None,
            person_card=dict(person_card) if isinstance(person_card, dict) else None,
        )

    def with_edits(self, edits: Optional[dict[str, Any]]) -> DurableWriteProposal:
        if not edits:
            return self
        if self.person_card is not None:
            return self._with_person_card_edits(edits)
        title = str(edits.get("title") or self.title).strip() or self.title
        body = str(edits.get("body") if "body" in edits else self.body).strip()
        snapshot = dict(self.apply_snapshot)
        inner = dict(snapshot.get("payload") or {})
        if "title" in edits:
            inner["title"] = title
        if "body" in edits:
            inner["content"] = body
            inner["description"] = body
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
            person_card=self.person_card,
        )

    def _with_person_card_edits(self, edits: dict[str, Any]) -> DurableWriteProposal:
        from app.services.person_confirm_proposal import (
            apply_person_card_edits,
            count_person_card_fields,
            _content_from_person_card,
        )

        person_card = apply_person_card_edits(
            person_card=dict(self.person_card or {}),
            edits=edits,
        )
        person_card.pop("insufficient_fields", None)
        if count_person_card_fields(person_card) < 2:
            # Keep proposal but mark insufficient fields for apply gate.
            person_card = {**person_card, "insufficient_fields": True}
        content = _content_from_person_card(person_card) or self.body
        title = content.split(".", 1)[0].strip() or self.title
        snapshot = dict(self.apply_snapshot)
        inner = dict(snapshot.get("payload") or {})
        metadata = dict(inner.get("metadata") or {})
        metadata["fact_kind"] = "relationship"
        metadata["memory_category"] = "People"
        relationship = str(person_card.get("relationship") or "").strip()
        display_name = str(person_card.get("display_name") or "").strip()
        birthday = str(person_card.get("birthday") or "").strip()
        notes = str(person_card.get("notes") or "").strip()
        if relationship:
            metadata["relationship"] = relationship
        if display_name:
            metadata["entity_label"] = display_name.casefold().replace(" ", "_")
        if birthday:
            metadata["normalized_date"] = birthday
            metadata["fact_kind"] = "relationship"
        person_meta = {
            key: person_card.get(key)
            for key in ("display_name", "relationship", "birthday", "notes")
            if str(person_card.get(key) or "").strip()
        }
        if notes:
            person_meta["notes"] = notes
        metadata["person_card"] = person_meta
        if relationship:
            metadata["topic_fingerprint"] = f"fact:relationship:{relationship}"
        inner["content"] = content
        inner["metadata"] = metadata
        snapshot["payload"] = inner
        return DurableWriteProposal(
            write_kind=self.write_kind,
            title=title,
            body=content,
            target_label=self.target_label,
            editable_fields=self.editable_fields,
            apply_snapshot=snapshot,
            proposal_id=self.proposal_id,
            merge_target_title=self.merge_target_title,
            risk_level=self.risk_level,
            custom_assistant_prompt=self.custom_assistant_prompt,
            person_card=person_card,
        )

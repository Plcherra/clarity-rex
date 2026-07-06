"""Refine durable write proposal copy from messy voice/chat transcripts."""

from __future__ import annotations

import json
import re
from typing import Any, Optional

from app.services.ai_service import AIService
from app.services.durable_write_proposal import DurableWriteProposal

_REFINABLE_KINDS = frozenset({"memory", "plan", "open_thread"})
_DISFLUENCY_PATTERN = re.compile(
    r"\b(?:i think|like|you know|um+|uh+|maybe|sort of|kind of|gonna|wanna|gotta)\b",
    re.IGNORECASE,
)
_STT_ARTIFACT_PATTERN = re.compile(r"\buser has a\b", re.IGNORECASE)
_REPEAT_WORD_PATTERN = re.compile(r"\b(\w+)\s+\1\b", re.IGNORECASE)


def needs_proposal_copy_refinement(proposal: DurableWriteProposal) -> bool:
    if proposal.write_kind not in _REFINABLE_KINDS:
        return False
    title = str(proposal.title or "").strip()
    body = str(proposal.body or "").strip()
    if not body:
        return False
    if proposal.write_kind in {"plan", "open_thread"} and (
        len(body.split()) >= 12
        or len(title) > 48
        or title == body
        or _DISFLUENCY_PATTERN.search(body) is not None
        or _REPEAT_WORD_PATTERN.search(body) is not None
        or _STT_ARTIFACT_PATTERN.search(body) is not None
    ):
        return True
    if len(body.split()) >= 18:
        return True
    if title and body and title == body:
        return (
            len(body.split()) >= 10
            or len(body) > 96
            or _DISFLUENCY_PATTERN.search(body) is not None
            or _REPEAT_WORD_PATTERN.search(body) is not None
            or _STT_ARTIFACT_PATTERN.search(body) is not None
        )
    if _DISFLUENCY_PATTERN.search(body):
        return True
    if _STT_ARTIFACT_PATTERN.search(body):
        return True
    if _REPEAT_WORD_PATTERN.search(body):
        return True
    return len(body) > 96


class DurableWriteProposalRefiner:
    def __init__(self, ai_service: AIService) -> None:
        self.ai_service = ai_service

    async def refine(
        self,
        proposal: DurableWriteProposal,
        *,
        conversation_messages: list[dict],
        user_message: str,
    ) -> DurableWriteProposal:
        if not needs_proposal_copy_refinement(proposal):
            return proposal

        context = _recent_conversation_text(conversation_messages, user_message)
        prompt = _refinement_prompt(
            write_kind=proposal.write_kind,
            draft_title=proposal.title,
            draft_body=proposal.body,
            conversation_context=context,
        )
        try:
            result = await self.ai_service.generate_response(
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "You draft confirm-card title and description for Clarity saves. "
                            "Return only JSON with keys title and body. "
                            "Title: short label, max 72 characters. "
                            "Body: 1-3 clear sentences with the durable fact or goal. "
                            "Fix speech-to-text errors. Do not copy rambling transcript verbatim."
                        ),
                    },
                    {"role": "user", "content": prompt},
                ],
                max_tokens=220,
                max_prompt_characters=8000,
            )
        except Exception:
            return proposal

        parsed = _parse_refinement_response(result.text)
        if parsed is None:
            return proposal

        title = str(parsed.get("title") or "").strip()
        body = str(parsed.get("body") or "").strip()
        if not title or not body:
            return proposal

        refined = proposal.with_edits({"title": title, "body": body})
        if proposal.write_kind == "open_thread":
            snapshot = dict(refined.apply_snapshot)
            payload = dict(snapshot.get("payload") or {})
            payload["summary"] = body
            snapshot["payload"] = payload
            return DurableWriteProposal(
                write_kind=refined.write_kind,
                title=refined.title,
                body=refined.body,
                target_label=refined.target_label,
                editable_fields=refined.editable_fields,
                apply_snapshot=snapshot,
                proposal_id=refined.proposal_id,
                merge_target_title=refined.merge_target_title,
                risk_level=refined.risk_level,
                custom_assistant_prompt=refined.custom_assistant_prompt,
            )
        return refined


def _recent_conversation_text(
    conversation_messages: list[dict],
    user_message: str,
) -> str:
    lines: list[str] = []
    for message in conversation_messages[-8:]:
        role = str(message.get("role") or "user").strip().lower()
        content = str(message.get("content") or "").strip()
        if not content:
            continue
        label = "User" if role == "user" else "Assistant"
        lines.append(f"{label}: {content}")
    current = str(user_message or "").strip()
    if current and (not lines or not lines[-1].endswith(current)):
        lines.append(f"User: {current}")
    return "\n".join(lines)


def _refinement_prompt(
    *,
    write_kind: str,
    draft_title: str,
    draft_body: str,
    conversation_context: str,
) -> str:
    kind_label = {
        "memory": "saved memory note for Clarity Knows",
        "plan": "goal/plan for the Goals tab",
        "open_thread": "habit/accountability open thread for Goals",
    }.get(write_kind, "saved item")
    return (
        f"Draft a confirm card for a {kind_label}.\n\n"
        f"Conversation context:\n{conversation_context or '(none)'}\n\n"
        f"Draft title:\n{draft_title}\n\n"
        f"Draft body:\n{draft_body}\n\n"
        "Write a clean title and body the user can review before saving."
    )


def _parse_refinement_response(text: str) -> Optional[dict[str, Any]]:
    raw = str(text or "").strip()
    if not raw:
        return None
    if raw.startswith("```"):
        raw = raw.strip("`")
        if raw.lower().startswith("json"):
            raw = raw[4:].strip()
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        start = raw.find("{")
        end = raw.rfind("}")
        if start < 0 or end <= start:
            return None
        try:
            parsed = json.loads(raw[start : end + 1])
        except json.JSONDecodeError:
            return None
    if not isinstance(parsed, dict):
        return None
    return parsed

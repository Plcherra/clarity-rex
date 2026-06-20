"""Experimental layered Rex Brain prompt contracts.

NON-PRODUCTION FOR LAUNCH.

MVP production chat and voice use ChatService + SimpleRexBrain.
"""

from dataclasses import dataclass, field
from typing import Any

from app.services.rex_brain_contracts import RexOutputMode, RexThinkingLayer

REX_BRAIN_PROMPT_VERSION = "rex_brain_prompt_v1"
MAX_LAYER_PROMPT_CHARACTERS = 900

_SHARED_SAFETY_RULES = """
Shared rules: use only provided context/saved memory; do not imply live bank access. Do not reveal hidden reasoning. For live/current research, ask before claiming external verification. On risky financial, legal, tax, medical, immigration, or security topics, avoid false certainty. Never claim an app action succeeded unless execution metadata confirms it.
""".strip()

_OUTPUT_CONTRACT_RULES = """
Output: user-facing text only; stay in selected layer.
""".strip()

_LAYER_PROMPTS: dict[RexThinkingLayer, str] = {
    RexThinkingLayer.FAST: """
Layer 0 Fast / Casual: answer quickly in Rex's natural voice. Use 1-4 short chat paragraphs or 1-3 spoken sentences. Avoid heavy analysis, planning, and detailed financial math. Ask at most one clarification question.
""".strip(),
    RexThinkingLayer.CONTEXTUAL: """
Layer 1 Contextual Recall: use relevant memory and context. Corrections and newer facts override older memory. Admit when memory or context is missing. Keep recall concise; avoid dumping all remembered context.
""".strip(),
    RexThinkingLayer.ANALYTICAL: """
Layer 2 Analytical / Financial: analyze provided Clarity facts, numbers, transactions, budgets, and trends. Separate facts, assumptions, concise math, and recommendations. Flag stale/missing data. Prioritize unusual spending, budget drift, upcoming commitments, and goal risks. Never say you checked the user's bank directly. Ask for confirmation unless execution metadata confirms mutations.
""".strip(),
    RexThinkingLayer.STRATEGIC: """
Layer 3 Strategic / Goals: connect finances, goals, priorities, constraints, memory, and commitments. Compare tradeoffs and practical costs. Give 1-3 priorities, a small decision frame, and next actions. For plans, include objective, constraints, milestones, open decisions, and next revision point. Preserve user autonomy: recommend, do not command. State assumptions when context is incomplete.
""".strip(),
    RexThinkingLayer.REFLECTIVE: """
Layer 4 Reflective / Consistency Check: check contradictions, assumptions, unsupported claims, and stale context. For reviews, list stale goals, outdated memories, duplicate commitments, and blind spots with evidence. For action previews, name action, target, ambiguity, and confirmation needed. Do not expose hidden reasoning; give a short self-check and corrected answer. Prefer correction over defensiveness when user says Rex was wrong.
""".strip(),
    RexThinkingLayer.COACHING: """
Layer 5 Coaching / Forward-Looking: be warm, direct, grounded, and practical. Use provided goals, rules, commitments, and preferences. Do not fake certainty or invent personal history. Tie motivation to one specific next action. Avoid generic pep talks; make advice personal and usable.
""".strip(),
}

_LAYER_OUTPUT_MODES = {
    RexThinkingLayer.FAST: RexOutputMode.CONCISE_TEXT,
    RexThinkingLayer.CONTEXTUAL: RexOutputMode.GROUNDED_TEXT,
    RexThinkingLayer.ANALYTICAL: RexOutputMode.ANALYSIS,
    RexThinkingLayer.STRATEGIC: RexOutputMode.STRATEGIC_PLAN,
    RexThinkingLayer.REFLECTIVE: RexOutputMode.REFLECTIVE_CHECK,
    RexThinkingLayer.COACHING: RexOutputMode.COACHING,
}

_LAYER_SCHEMAS: dict[RexThinkingLayer, dict[str, Any]] = {
    RexThinkingLayer.FAST: {
        "type": "object",
        "required": ["answer", "needs_clarification"],
        "properties": {
            "answer": {"type": "string"},
            "needs_clarification": {"type": "boolean"},
        },
    },
    RexThinkingLayer.CONTEXTUAL: {
        "type": "object",
        "required": ["answer", "used_context", "missing_context"],
        "properties": {
            "answer": {"type": "string"},
            "used_context": {"type": "array", "items": {"type": "string"}},
            "missing_context": {"type": "array", "items": {"type": "string"}},
        },
    },
    RexThinkingLayer.ANALYTICAL: {
        "type": "object",
        "required": ["answer", "facts", "assumptions", "recommendations"],
        "properties": {
            "answer": {"type": "string"},
            "facts": {"type": "array", "items": {"type": "string"}},
            "assumptions": {"type": "array", "items": {"type": "string"}},
            "recommendations": {"type": "array", "items": {"type": "string"}},
        },
    },
    RexThinkingLayer.STRATEGIC: {
        "type": "object",
        "required": ["answer", "tradeoffs", "next_actions"],
        "properties": {
            "answer": {"type": "string"},
            "tradeoffs": {"type": "array", "items": {"type": "string"}},
            "next_actions": {"type": "array", "items": {"type": "string"}},
        },
    },
    RexThinkingLayer.REFLECTIVE: {
        "type": "object",
        "required": ["answer", "self_check", "uncertainties"],
        "properties": {
            "answer": {"type": "string"},
            "self_check": {"type": "array", "items": {"type": "string"}},
            "uncertainties": {"type": "array", "items": {"type": "string"}},
        },
    },
    RexThinkingLayer.COACHING: {
        "type": "object",
        "required": ["answer", "next_action"],
        "properties": {
            "answer": {"type": "string"},
            "next_action": {"type": "string"},
        },
    },
}


@dataclass(frozen=True)
class RexPromptContract:
    layer: RexThinkingLayer
    version: str
    output_mode: RexOutputMode
    system_prompt: str
    metadata_schema: dict[str, Any] = field(default_factory=dict)

    def metadata(self) -> dict[str, Any]:
        return {
            "layer": self.layer.value,
            "prompt_version": self.version,
            "output_mode": self.output_mode.value,
            "schema_required": list(self.metadata_schema.get("required", [])),
        }


def get_rex_prompt_contract(layer: RexThinkingLayer) -> RexPromptContract:
    prompt = _compose_layer_prompt(layer)
    return RexPromptContract(
        layer=layer,
        version=f"{REX_BRAIN_PROMPT_VERSION}:{layer.value}",
        output_mode=_LAYER_OUTPUT_MODES[layer],
        system_prompt=prompt,
        metadata_schema=_LAYER_SCHEMAS[layer],
    )


def all_rex_prompt_contracts() -> tuple[RexPromptContract, ...]:
    return tuple(get_rex_prompt_contract(layer) for layer in RexThinkingLayer)


def _compose_layer_prompt(layer: RexThinkingLayer) -> str:
    return "\n\n".join(
        [
            f"Rex Brain version: {REX_BRAIN_PROMPT_VERSION}",
            _SHARED_SAFETY_RULES,
            _OUTPUT_CONTRACT_RULES,
            _LAYER_PROMPTS[layer],
        ]
    )

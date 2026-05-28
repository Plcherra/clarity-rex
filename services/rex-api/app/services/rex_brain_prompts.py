from dataclasses import dataclass, field
from typing import Any

from app.services.rex_brain_contracts import RexOutputMode, RexThinkingLayer

REX_BRAIN_PROMPT_VERSION = "rex_brain_prompt_v1"
MAX_LAYER_PROMPT_CHARACTERS = 4200

_SHARED_SAFETY_RULES = """
Shared Rex Brain rules:
- Use only the context provided in the request; do not imply direct bank access, live account access, or background monitoring.
- Financial context is a Clarity app snapshot and may be incomplete, delayed, or degraded. State important limits when they affect the answer.
- Do not reveal hidden chain-of-thought. Give concise reasoning summaries, assumptions, calculations, and conclusions instead.
- Never claim a memory, financial record, goal, budget, or transaction was changed unless an execution result says the write succeeded.
- For risky financial, legal, tax, medical, or immigration topics, be useful but cautious and recommend a qualified professional when appropriate.
- Prefer clear next actions over vague motivation.
""".strip()

_OUTPUT_CONTRACT_RULES = """
Output contract:
- Return user-facing assistant text by default.
- If internal metadata is requested by the backend, it must follow the layer schema and must not include raw private context.
- Keep answers scoped to the selected layer; do not upgrade yourself to a deeper layer inside the prompt.
""".strip()

_LAYER_PROMPTS: dict[RexThinkingLayer, str] = {
    RexThinkingLayer.FAST: """
Layer 0 Fast / Casual:
- Answer quickly in Rex's direct, natural voice.
- Use 1-4 short paragraphs for chat or 1-3 spoken sentences for voice.
- Do not perform heavy analysis, long planning, or detailed financial calculations.
- Ask at most one clarification question if the request cannot be answered.
- If the user asks for deeper analysis, acknowledge and let routing escalate on the next turn or explicit Deep Think request.
""".strip(),
    RexThinkingLayer.CONTEXTUAL: """
Layer 1 Contextual Recall:
- Use relevant memory, conversation summary, and current context when provided.
- Corrections and newer verified facts override older memory.
- Admit when memory or context is missing instead of inventing details.
- Keep recall concise; answer the current question rather than dumping all remembered context.
- Separate remembered facts from current advice when both are present.
""".strip(),
    RexThinkingLayer.ANALYTICAL: """
Layer 2 Analytical / Financial:
- Analyze facts, numbers, transactions, categories, budgets, and trends from provided Clarity context.
- Separate facts, calculations, assumptions, and recommendations.
- Show concise math when it materially improves trust.
- Flag missing or stale data before making strong claims.
- Never say you checked the user's bank directly; you only see the provided Clarity snapshot.
- For create/update/delete requests, ask for confirmation unless an execution result already exists.
""".strip(),
    RexThinkingLayer.STRATEGIC: """
Layer 3 Strategic / Goals:
- Connect finances, goals, priorities, constraints, memory, and pending commitments.
- Compare tradeoffs and name the practical cost of each option.
- Produce a small decision frame and next actions.
- Preserve user autonomy: recommend, do not command.
- State assumptions clearly when context is incomplete.
- Prefer plans that can be reviewed in later turns.
""".strip(),
    RexThinkingLayer.REFLECTIVE: """
Layer 4 Reflective / Consistency Check:
- Check the draft answer or current reasoning for contradictions, missing assumptions, unsupported claims, and stale context.
- Do not expose hidden chain-of-thought; provide a short self-check summary and the corrected user-facing answer.
- If prior context is insufficient, say what is uncertain and what would resolve it.
- Prefer correction over defensiveness when the user says Rex was wrong.
""".strip(),
    RexThinkingLayer.COACHING: """
Layer 5 Coaching / Forward-Looking:
- Be warm, direct, grounded, and practical.
- Use provided goals, rules, commitments, and preferences when available.
- Do not fake certainty or invent personal history.
- Keep motivation tied to one specific next action.
- Avoid generic pep talks; make the advice feel personal and usable.
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
            f"Rex Brain prompt version: {REX_BRAIN_PROMPT_VERSION}",
            _SHARED_SAFETY_RULES,
            _OUTPUT_CONTRACT_RULES,
            _LAYER_PROMPTS[layer],
        ]
    )

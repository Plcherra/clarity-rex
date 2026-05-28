from app.services.rex_brain_contracts import RexOutputMode, RexThinkingLayer
from app.services.rex_brain_prompts import (
    MAX_LAYER_PROMPT_CHARACTERS,
    REX_BRAIN_PROMPT_VERSION,
    all_rex_prompt_contracts,
    get_rex_prompt_contract,
)


def test_every_thinking_layer_has_a_versioned_prompt_contract():
    contracts = all_rex_prompt_contracts()

    assert {contract.layer for contract in contracts} == set(RexThinkingLayer)
    assert all(
        contract.version == f"{REX_BRAIN_PROMPT_VERSION}:{contract.layer.value}"
        for contract in contracts
    )
    assert all(contract.system_prompt for contract in contracts)
    assert all(contract.metadata_schema["type"] == "object" for contract in contracts)


def test_prompt_contracts_include_shared_safety_and_data_boundaries():
    for contract in all_rex_prompt_contracts():
        prompt = contract.system_prompt.lower()
        assert "do not imply direct bank access" in prompt
        assert "financial context is a clarity app snapshot" in prompt
        assert "do not reveal hidden chain-of-thought" in prompt
        assert "never claim a memory, financial record, goal, budget, or transaction was changed" in prompt
        assert "qualified professional" in prompt


def test_layer_prompts_have_distinct_output_modes_and_schema_requirements():
    expectations = {
        RexThinkingLayer.FAST: (RexOutputMode.CONCISE_TEXT, {"answer", "needs_clarification"}),
        RexThinkingLayer.CONTEXTUAL: (RexOutputMode.GROUNDED_TEXT, {"answer", "used_context", "missing_context"}),
        RexThinkingLayer.ANALYTICAL: (RexOutputMode.ANALYSIS, {"answer", "facts", "assumptions", "recommendations"}),
        RexThinkingLayer.STRATEGIC: (RexOutputMode.STRATEGIC_PLAN, {"answer", "tradeoffs", "next_actions"}),
        RexThinkingLayer.REFLECTIVE: (RexOutputMode.REFLECTIVE_CHECK, {"answer", "self_check", "uncertainties"}),
        RexThinkingLayer.COACHING: (RexOutputMode.COACHING, {"answer", "next_action"}),
    }

    for layer, (output_mode, required_keys) in expectations.items():
        contract = get_rex_prompt_contract(layer)
        assert contract.output_mode == output_mode
        assert set(contract.metadata_schema["required"]) == required_keys


def test_fast_prompt_stays_latency_focused_and_avoids_deep_analysis():
    prompt = get_rex_prompt_contract(RexThinkingLayer.FAST).system_prompt.lower()

    assert "answer quickly" in prompt
    assert "1-3 spoken sentences" in prompt
    assert "do not perform heavy analysis" in prompt
    assert "ask at most one clarification" in prompt


def test_contextual_prompt_prioritizes_corrections_and_missing_context():
    prompt = get_rex_prompt_contract(RexThinkingLayer.CONTEXTUAL).system_prompt.lower()

    assert "corrections and newer verified facts override older memory" in prompt
    assert "admit when memory or context is missing" in prompt
    assert "dumping all remembered context" in prompt


def test_analytical_and_strategic_prompts_separate_facts_and_tradeoffs():
    analytical = get_rex_prompt_contract(RexThinkingLayer.ANALYTICAL).system_prompt.lower()
    strategic = get_rex_prompt_contract(RexThinkingLayer.STRATEGIC).system_prompt.lower()

    assert "separate facts, calculations, assumptions, and recommendations" in analytical
    assert "never say you checked the user's bank directly" in analytical
    assert "compare tradeoffs" in strategic
    assert "preserve user autonomy" in strategic
    assert "next actions" in strategic


def test_reflective_and_coaching_prompts_are_safe_for_user_facing_answers():
    reflective = get_rex_prompt_contract(RexThinkingLayer.REFLECTIVE).system_prompt.lower()
    coaching = get_rex_prompt_contract(RexThinkingLayer.COACHING).system_prompt.lower()

    assert "corrected user-facing answer" in reflective
    assert "prefer correction over defensiveness" in reflective
    assert "do not fake certainty" in coaching
    assert "avoid generic pep talks" in coaching


def test_prompt_metadata_is_safe_and_does_not_include_prompt_text_or_raw_context():
    contract = get_rex_prompt_contract(RexThinkingLayer.ANALYTICAL)
    metadata = contract.metadata()

    assert metadata == {
        "layer": "layer_2_analytical",
        "prompt_version": "rex_brain_prompt_v1:layer_2_analytical",
        "output_mode": "analysis",
        "schema_required": ["answer", "facts", "assumptions", "recommendations"],
    }
    assert "system_prompt" not in metadata
    assert "financial" not in metadata
    assert "memory" not in metadata


def test_layer_prompts_stay_within_size_budget():
    for contract in all_rex_prompt_contracts():
        assert len(contract.system_prompt) <= MAX_LAYER_PROMPT_CHARACTERS

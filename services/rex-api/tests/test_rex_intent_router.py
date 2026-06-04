from app.services.rex_intent_router import RexIntent, RexIntentRouter


def test_router_classifies_casual_chat_without_context_loads():
    decision = RexIntentRouter().classify("Hey Rex")

    assert decision.intent == RexIntent.CASUAL
    assert not decision.should_load_long_term_memory
    assert not decision.should_load_profile_memory
    assert not decision.should_load_structured_memory
    assert not decision.should_load_goal_context
    assert not decision.should_load_accountability


def test_router_classifies_simple_memory_save_without_context_loads():
    decision = RexIntentRouter().classify("My mom's birthday is June 18")

    assert decision.intent == RexIntent.MEMORY_SAVE
    assert not decision.should_load_long_term_memory
    assert not decision.should_load_structured_memory


def test_router_classifies_memory_correction_with_memory_context():
    decision = RexIntentRouter().classify("No, it's Somerville with one m")

    assert decision.intent == RexIntent.MEMORY_UPDATE
    assert decision.should_load_long_term_memory
    assert decision.should_load_profile_memory
    assert decision.should_load_structured_memory


def test_router_classifies_memory_recall_with_memory_context():
    decision = RexIntentRouter().classify("Do you remember my mom's birthday?")

    assert decision.intent == RexIntent.MEMORY_RECALL
    assert decision.should_load_long_term_memory
    assert decision.should_load_structured_memory
    assert not decision.should_load_goal_context


def test_router_classifies_goals_with_goal_context_only():
    decision = RexIntentRouter().classify("How am I doing on my goals?")

    assert decision.intent == RexIntent.GOAL_OR_COMMITMENT
    assert not decision.should_load_long_term_memory
    assert not decision.should_load_structured_memory
    assert decision.should_load_goal_context
    assert decision.should_load_accountability


def test_router_loads_structured_memory_for_accountability_patterns():
    decision = RexIntentRouter().classify("I ordered DoorDash again.")

    assert decision.intent == RexIntent.GOAL_OR_COMMITMENT
    assert not decision.should_load_long_term_memory
    assert decision.should_load_structured_memory
    assert decision.should_load_goal_context
    assert decision.should_load_accountability


def test_router_classifies_finance_without_memory_context():
    decision = RexIntentRouter().classify("How much did I spend this week?")

    assert decision.intent == RexIntent.FINANCE
    assert decision.should_use_financial_context
    assert not decision.should_load_long_term_memory
    assert not decision.should_load_structured_memory
    assert not decision.should_load_goal_context


def test_router_classifies_deep_reasoning_as_explicit():
    decision = RexIntentRouter().classify("Deep think this budget problem")

    assert decision.intent == RexIntent.DEEP_REASONING
    assert decision.should_load_long_term_memory
    assert decision.should_load_structured_memory
    assert decision.should_load_goal_context

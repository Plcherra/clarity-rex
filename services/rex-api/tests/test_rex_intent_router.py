import pytest

from app.services.rex_intent_router import RexIntent, RexIntentRouter


def test_router_classifies_casual_chat_without_context_loads():
    decision = RexIntentRouter().classify("Hey Rex")

    assert decision.intent == RexIntent.CASUAL
    assert not decision.should_load_long_term_memory
    assert not decision.should_load_profile_memory
    assert not decision.should_load_structured_memory
    assert not decision.should_load_goal_context
    assert not decision.should_load_accountability


@pytest.mark.parametrize(
    "message",
    [
        "It's so hot up here.",
        "Yeah. Midsummer.",
        "So what can you do?",
        "I worked with two new employees, Aaron and Jessica.",
        "It went amazing because it was a pretty big, busy day.",
        "Everyone got a good heart.",
        "I meant Aaron.",
        "Can you help me balance work and rest?",
        "I saved that note for later.",
        "What is my Clarity account email?",
        "I was listening to $uicideboy$ earlier.",
    ],
)
def test_router_keeps_normal_voice_chat_off_finance_path(message):
    decision = RexIntentRouter().classify(
        message,
        has_financial_context=True,
    )

    assert decision.intent != RexIntent.FINANCE
    assert not decision.should_use_financial_context


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


def test_router_classifies_memory_delete_with_structured_memory_context():
    decision = RexIntentRouter().classify("Can you delete that event?")

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


def test_router_memory_recall_beats_attached_financial_context():
    decision = RexIntentRouter().classify(
        "Can you check if you have any chat talking about my mom?",
        has_financial_context=True,
    )

    assert decision.intent == RexIntent.MEMORY_RECALL
    assert decision.should_load_long_term_memory
    assert decision.should_load_profile_memory
    assert decision.should_load_structured_memory
    assert not decision.should_use_financial_context


def test_router_memory_information_question_beats_attached_financial_context():
    decision = RexIntentRouter().classify(
        "What information do you have?",
        has_financial_context=True,
    )

    assert decision.intent == RexIntent.MEMORY_RECALL
    assert decision.should_load_long_term_memory
    assert decision.should_load_structured_memory
    assert not decision.should_use_financial_context


@pytest.mark.parametrize(
    "message",
    [
        "Do you know anything about my friend Lara?",
        "Did I mention sending money?",
        "What did I say about money?",
        "Have we talked about my immigration plan?",
        "What did I tell you about my sister?",
        "Can you search our chats for my birthday?",
        "Can you search for June 18?",
        "Can you search in old chats for June 18?",
        "Do you remember anything about my mom's birthday?",
        "What did I say about games?",
        "Ok so you cannot actually find any chat I said June 18?",
        "Actually, do you remember anything about my mom's birthday?",
        "Remember anything that I talked about my mom?",
        "Right. But what does it mention about PC?",
        "The chat.",
        "What have I told you about my preferences?",
    ],
)
def test_router_classifies_generic_memory_recall_questions(message):
    decision = RexIntentRouter().classify(
        message,
        has_financial_context=True,
    )

    assert decision.intent == RexIntent.MEMORY_RECALL
    assert decision.should_load_long_term_memory
    assert decision.should_load_structured_memory
    assert not decision.should_use_financial_context


@pytest.mark.parametrize(
    "message",
    [
        "Do you know my bank balance?",
        "What do you know about my transactions?",
        "Can you tell me my budget?",
    ],
)
def test_router_keeps_financial_questions_on_finance_path(message):
    decision = RexIntentRouter().classify(
        message,
        has_financial_context=True,
    )

    assert decision.intent == RexIntent.FINANCE
    assert decision.should_use_financial_context
    assert not decision.should_load_long_term_memory


def test_router_memory_save_beats_attached_financial_context():
    decision = RexIntentRouter().classify(
        "Remember my mom's birthday is June 18",
        has_financial_context=True,
    )

    assert decision.intent == RexIntent.MEMORY_SAVE
    assert not decision.should_load_long_term_memory
    assert not decision.should_use_financial_context


@pytest.mark.parametrize(
    "message",
    [
        "Where am I located?",
        "Do you know where I'm located?",
        "What city do I live in?",
        "Do you know anything about me?",
        "What are my plans tonight?",
        "Do you know my mom's birthday?",
    ],
)
def test_router_classifies_voice_memory_recall_phrases(message):
    decision = RexIntentRouter().classify(message)

    assert decision.intent == RexIntent.MEMORY_RECALL
    assert decision.should_load_long_term_memory
    assert decision.should_load_profile_memory
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


@pytest.mark.parametrize(
    "message",
    [
        "Can I afford rent this month?",
        "Did payroll hit my account?",
        "How much money did I spend today?",
        "Show my savings account balance.",
        "Did I send Jessica money?",
        "What accounts do I have?",
        "Do I have $20 for gas?",
    ],
)
def test_router_classifies_clear_money_action_turns_as_finance(message):
    decision = RexIntentRouter().classify(message)

    assert decision.intent == RexIntent.FINANCE
    assert decision.should_use_financial_context


def test_router_keeps_financial_delete_on_finance_path():
    decision = RexIntentRouter().classify("Delete that transaction")

    assert decision.intent == RexIntent.FINANCE
    assert decision.should_use_financial_context
    assert not decision.should_load_long_term_memory


def test_router_classifies_deep_reasoning_as_explicit():
    decision = RexIntentRouter().classify("Deep think this budget problem")

    assert decision.intent == RexIntent.DEEP_REASONING
    assert decision.should_load_long_term_memory
    assert decision.should_load_structured_memory
    assert decision.should_load_goal_context

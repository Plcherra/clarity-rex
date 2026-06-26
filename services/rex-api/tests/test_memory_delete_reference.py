from app.services.memory_correction_intent_parser import MemoryCorrectionIntentParser
from app.services.memory_correction_types import CorrectionIntentType
from app.services.memory_delete_reference import (
    extract_reference_delete_target,
    is_delete_clarification_message,
    is_vague_delete_target,
)


def test_reference_delete_target_from_starting_as_phrase():
    target = extract_reference_delete_target("The one starting as 'be a goal...'")
    assert target == "be a goal"


def test_vague_delete_target_detects_generic_memory_request():
    assert is_vague_delete_target("a memory please")


def test_delete_clarification_after_failed_delete():
    history = [
        {
            "role": "assistant",
            "content": (
                "I couldn't find an active saved memory matching that, so I "
                "didn't delete anything."
            ),
        }
    ]
    assert is_delete_clarification_message("The one starting as be a goal", history)


def test_intent_parser_parses_reference_delete():
    intent = MemoryCorrectionIntentParser().detect_correction_intent(
        "The one starting as 'be a goal...'"
    )
    assert intent.intent_type == CorrectionIntentType.REMOVE_OBSOLETE
    assert "be a goal" in intent.old_value.casefold()


def test_intent_parser_delete_saved_commitment_targets_commitment():
    intent = MemoryCorrectionIntentParser().detect_correction_intent(
        "Can you delete the commitment we have saved?"
    )
    assert intent.intent_type == CorrectionIntentType.REMOVE_OBSOLETE
    assert intent.old_value == "commitment"
    assert intent.delete_scope_tables == ("commitments",)
    assert intent.is_vague_delete_reference is True

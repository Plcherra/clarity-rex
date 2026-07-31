"""Chat request validation and oversized finance-context recovery."""

import json

from pydantic import ValidationError

from app.models.chat import FINANCIAL_CONTEXT_MAX_CHARS, ChatRequest
from app.services.chat_request_validation import (
    chat_request_dropping_oversized_financial_context,
    is_only_financial_context_size_error,
    serializable_validation_errors,
)


def test_serializable_validation_errors_omit_non_json_ctx():
    try:
        ChatRequest(
            message="hello",
            financial_context={"blob": "y" * 40_000},
        )
    except ValidationError as error:
        details = serializable_validation_errors(error)
        assert details == [
            {
                "type": "value_error",
                "loc": ["financial_context"],
                "msg": (
                    "Value error, financial_context exceeds maximum size "
                    "of 32000 characters."
                ),
            }
        ]
        return
    raise AssertionError("expected ValidationError")


def test_drop_oversized_financial_context_recovers_request():
    payload = {
        "message": "What subscriptions do I have until Aug 6?",
        "stream": True,
        "financial_context": {"blob": "y" * 40_000},
    }
    try:
        ChatRequest(**payload)
    except ValidationError as error:
        assert is_only_financial_context_size_error(error)
        recovered = chat_request_dropping_oversized_financial_context(
            payload,
            error,
        )
        assert recovered is not None
        assert recovered.message.startswith("What subscriptions")
        assert recovered.financial_context is None
        return
    raise AssertionError("expected ValidationError")


def test_context_sized_against_json_length_is_kept():
    """The app trims against jsonEncode; a Python repr must not shrink the cap."""
    context = {
        "transactions": [
            {"id": f"tx-{index}", "merchant": "Coffee Shop", "amount": 5.25}
            for index in range(560)
        ]
    }
    encoded = json.dumps(context, separators=(",", ":"))
    assert len(encoded) <= FINANCIAL_CONTEXT_MAX_CHARS
    assert len(str(context)) > FINANCIAL_CONTEXT_MAX_CHARS

    request = ChatRequest(message="How much on coffee?", financial_context=context)
    assert request.financial_context == context


def test_drop_helper_ignores_unrelated_validation_errors():
    payload = {"message": ""}
    try:
        ChatRequest(**payload)
    except ValidationError as error:
        assert chat_request_dropping_oversized_financial_context(
            payload,
            error,
        ) is None
        return
    raise AssertionError("expected ValidationError")

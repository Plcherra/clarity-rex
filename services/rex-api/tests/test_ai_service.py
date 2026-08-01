import pytest
import httpx

from app.config import Settings
from app.services.ai_service import AIService, AIServiceError
from app.services.grok_usage import GrokUsage


def test_ai_service_parse_grok_response_text():
    service = AIService(Settings(grok_api_key="test-key", grok_model="grok-test"))
    text, tool_calls, finish_reason = service._parse_grok_choice(
        {
            "choices": [{"message": {"content": " Hello Rex "}}],
            "usage": {"prompt_tokens": 10, "completion_tokens": 5},
        }
    )
    assert text == "Hello Rex"
    assert tool_calls == ()
    assert finish_reason is None


def test_grok_usage_from_non_stream_response_shape():
    usage = GrokUsage.from_api_payload(
        {
            "choices": [{"message": {"content": "Hi"}}],
            "usage": {"prompt_tokens": 42, "completion_tokens": 18},
        }
    )
    assert usage is not None
    assert usage.total_tokens == 60


def test_ai_service_does_not_inject_personality_prompt():
    service = AIService(
        Settings(
            grok_api_key="test-key",
            grok_model="grok-test",
        )
    )
    messages = [
        {"role": "system", "content": "PromptService-owned system prompt"},
        {"role": "user", "content": "Hello Rex"},
    ]

    prompt_messages = service._validated_prompt_messages(messages)

    assert prompt_messages == messages


def test_ai_service_still_validates_required_grok_config():
    service = AIService(Settings(grok_api_key=None, grok_model="grok-test"))

    with pytest.raises(AIServiceError) as error:
        service._validated_prompt_messages([{"role": "user", "content": "Hello"}])

    assert error.value.detail == "Grok API key is not configured."


def test_ai_service_surfaces_grok_capacity_errors():
    service = AIService(Settings(grok_api_key="test-key", grok_model="grok-test"))
    response = httpx.Response(
        429,
        json={
            "code": "Some resource has been exhausted",
            "error": "The model is currently at capacity due to high demand.",
        },
    )

    error = service._http_status_error(response)

    assert error.status_code == 503
    assert error.detail == "The model is currently at capacity due to high demand."


def test_ai_service_surfaces_invalid_model_errors():
    service = AIService(Settings(grok_api_key="test-key", grok_model="grok-test"))
    response = httpx.Response(
        400,
        json={
            "code": "Client specified an invalid argument",
            "error": "Model not found: grok-test",
        },
    )

    error = service._http_status_error(response)

    assert error.status_code == 502
    assert error.detail == "Model not found: grok-test"


def test_ai_service_payload_uses_default_model_without_override():
    service = AIService(Settings(grok_api_key="test-key", grok_model="grok-default"))
    messages = [{"role": "user", "content": "Hello"}]

    payload = service._payload(
        messages=service._validated_prompt_messages(messages),
        stream=False,
    )

    assert payload == {
        "model": "grok-default",
        "messages": messages,
        "stream": False,
    }


def test_ai_service_preserves_multimodal_content_parts():
    service = AIService(Settings(grok_api_key="test-key", grok_model="grok-default"))
    messages = [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": "What is in this image?"},
                {
                    "type": "image_url",
                    "image_url": {
                        "url": "data:image/png;base64,aW1hZ2U=",
                        "detail": "auto",
                    },
                },
            ],
        }
    ]

    prompt_messages = service._validated_prompt_messages(messages)

    assert prompt_messages == messages


def test_ai_service_payload_uses_model_override_and_max_tokens():
    service = AIService(Settings(grok_api_key="test-key", grok_model="grok-default"))
    messages = [{"role": "user", "content": "Hello"}]

    payload = service._payload(
        messages=service._validated_prompt_messages(
            messages,
            model_override="grok-reasoning",
        ),
        stream=True,
        model_override="grok-reasoning",
        max_tokens=3000,
    )

    assert payload == {
        "model": "grok-reasoning",
        "messages": messages,
        "stream": True,
        "stream_options": {"include_usage": True},
        "max_tokens": 3000,
    }


def test_ai_service_enforces_per_route_prompt_limit():
    service = AIService(Settings(grok_api_key="test-key", grok_model="grok-default"))

    with pytest.raises(AIServiceError) as error:
        service._validated_prompt_messages(
            [{"role": "user", "content": "x" * 20}],
            max_prompt_characters=10,
        )

    assert error.value.status_code == 400
    assert error.value.detail == (
        "Message context is too large. Shorten the file or start a new chat."
    )


def test_ai_service_allows_override_when_default_model_is_missing():
    service = AIService(Settings(grok_api_key="test-key", grok_model=None))

    messages = service._validated_prompt_messages(
        [{"role": "user", "content": "Hello"}],
        model_override="grok-fast",
    )

    assert messages == [{"role": "user", "content": "Hello"}]


def test_ai_service_still_requires_some_model_when_no_override_exists():
    service = AIService(Settings(grok_api_key="test-key", grok_model=None))

    with pytest.raises(AIServiceError) as error:
        service._validated_prompt_messages([{"role": "user", "content": "Hello"}])

    assert error.value.detail == "Grok model is not configured."

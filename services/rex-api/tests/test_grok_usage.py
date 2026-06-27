import pytest

from app.services.grok_usage import GrokUsage


def test_grok_usage_cost_cents_from_ticks():
    usage = GrokUsage(
        prompt_tokens=100,
        completion_tokens=50,
        cost_in_usd_ticks=37_756_000,
    )
    assert usage.cost_cents() == pytest.approx(0.37756)


def test_grok_usage_from_api_payload_with_split_tokens():
    usage = GrokUsage.from_api_payload(
        {
            "usage": {
                "prompt_tokens": 120,
                "completion_tokens": 80,
                "total_tokens": 200,
                "cost_in_usd_ticks": 50_000_000,
            }
        }
    )

    assert usage is not None
    assert usage.prompt_tokens == 120
    assert usage.completion_tokens == 80
    assert usage.total_tokens == 200
    assert usage.cost_cents() == pytest.approx(0.5)


def test_grok_usage_from_api_payload_with_total_only():
    usage = GrokUsage.from_api_payload({"usage": {"total_tokens": 350}})

    assert usage is not None
    assert usage.prompt_tokens == 0
    assert usage.completion_tokens == 350
    assert usage.total_tokens == 350


def test_grok_usage_from_api_payload_with_xai_input_output_tokens():
    usage = GrokUsage.from_api_payload(
        {
            "usage": {
                "input_tokens": 90,
                "output_tokens": 10,
                "total_tokens": 100,
            }
        }
    )

    assert usage is not None
    assert usage.prompt_tokens == 90
    assert usage.completion_tokens == 10


def test_grok_usage_returns_none_when_missing():
    assert GrokUsage.from_api_payload({}) is None
    assert GrokUsage.from_api_payload({"usage": {}}) is None

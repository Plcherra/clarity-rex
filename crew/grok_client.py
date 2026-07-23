"""Resilient xAI Grok client for the Clarity Crew.

CrewAI raises ``ValueError: Invalid response from LLM call - None or empty`` when
the model returns an empty completion. This happens with Grok for two main
reasons:

1. Reasoning models (``grok-3-mini``) can spend their whole token budget on
   hidden reasoning and return empty visible content — worse when max_tokens is
   small. We mitigate with a modest ``reasoning_effort`` and a sane token cap.
2. Transient rate limits / hiccups return empty or error responses.

``ResilientGrokLLM`` wraps CrewAI's ``LLM`` and retries (up to N times with a
short backoff) whenever a call returns None/empty or raises, so a single blip
does not kill the whole crew run.
"""

from __future__ import annotations

import logging
import os
import time
from typing import Any

from crewai import LLM

log = logging.getLogger("clarity_crew.grok")


class ResilientGrokLLM(LLM):
    """CrewAI LLM that survives Grok's intermittent empty responses.

    Reasoning models (``grok-3-mini``) sometimes emit only hidden reasoning and
    empty visible content inside CrewAI's tool loop. Because a low temperature is
    near-deterministic, a plain retry reproduces the same empty. So we:

    1. Retry with **escalating temperature** so the model takes a different path.
    2. As a last resort, delegate one call to a **non-reasoning fallback model**
       (e.g. ``xai/grok-3``), which reliably returns visible content.
    """

    def __init__(
        self,
        *args: Any,
        max_empty_retries: int = 3,
        retry_delay: float = 3.0,
        retry_temperatures: list[float] | None = None,
        fallback_llm: "LLM | None" = None,
        **kwargs: Any,
    ) -> None:
        super().__init__(*args, **kwargs)
        self._max_empty_retries = max(1, max_empty_retries)
        self._retry_delay = retry_delay
        self._retry_temperatures = retry_temperatures or [0.5, 0.9]
        self._fallback_llm = fallback_llm

    @staticmethod
    def _is_empty(result: Any) -> bool:
        if result is None:
            return True
        if isinstance(result, str) and result.strip() == "":
            return True
        return False

    def call(
        self,
        messages: str | list[dict[str, str]],
        tools: list[dict] | None = None,
        callbacks: list[Any] | None = None,
        available_functions: dict[str, Any] | None = None,
        from_task: Any | None = None,
        from_agent: Any | None = None,
    ) -> str | Any:
        original_temperature = self.temperature
        last_error: Exception | None = None
        try:
            for attempt in range(1, self._max_empty_retries + 1):
                # Escalate temperature on later attempts to escape a stuck empty.
                if attempt > 1 and self._retry_temperatures:
                    self.temperature = self._retry_temperatures[
                        min(attempt - 2, len(self._retry_temperatures) - 1)
                    ]
                try:
                    result = super().call(
                        messages,
                        tools=tools,
                        callbacks=callbacks,
                        available_functions=available_functions,
                        from_task=from_task,
                        from_agent=from_agent,
                    )
                except Exception as exc:  # noqa: BLE001 - retry transient failures
                    last_error = exc
                    log.warning(
                        "Grok call raised on attempt %d/%d: %s",
                        attempt,
                        self._max_empty_retries,
                        exc,
                    )
                    result = None

                if not self._is_empty(result):
                    return result

                if attempt < self._max_empty_retries:
                    delay = self._retry_delay * attempt  # linear backoff
                    log.warning(
                        "Empty/failed Grok response (attempt %d/%d); retrying in "
                        "%.1fs at temperature %.2f",
                        attempt,
                        self._max_empty_retries,
                        delay,
                        self.temperature,
                    )
                    time.sleep(delay)
        finally:
            self.temperature = original_temperature

        # Last resort: hand this one call to the non-reasoning fallback model.
        if self._fallback_llm is not None:
            log.warning(
                "Falling back to non-reasoning model '%s' after %d empty Grok "
                "responses.",
                getattr(self._fallback_llm, "model", "?"),
                self._max_empty_retries,
            )
            try:
                result = self._fallback_llm.call(
                    messages,
                    tools=tools,
                    callbacks=callbacks,
                    available_functions=available_functions,
                    from_task=from_task,
                    from_agent=from_agent,
                )
                if not self._is_empty(result):
                    return result
            except Exception as exc:  # noqa: BLE001
                last_error = exc

        if last_error is not None:
            raise RuntimeError(
                f"Grok LLM failed after {self._max_empty_retries} attempts "
                f"(and fallback): {last_error}"
            ) from last_error
        raise RuntimeError(
            "Grok returned empty responses after "
            f"{self._max_empty_retries} attempts and the fallback model. "
            "Set MODEL=xai/grok-3 (non-reasoning) in .env for the most reliable runs."
        )


def build_grok_llm() -> ResilientGrokLLM:
    """Build the resilient Grok LLM from environment configuration."""
    model = os.environ.get("MODEL", "xai/grok-3-mini")
    temperature = float(os.environ.get("TEMPERATURE", "0.1"))
    max_tokens = int(os.environ.get("MAX_TOKENS", "4000"))
    empty_retries = int(os.environ.get("LLM_EMPTY_RETRIES", "3"))
    retry_delay = float(os.environ.get("LLM_RETRY_DELAY", "3"))
    api_key = os.environ.get("XAI_API_KEY")
    api_retries = int(os.environ.get("LLM_API_RETRIES", "3"))

    kwargs: dict[str, Any] = {
        "model": model,
        "temperature": temperature,
        "api_key": api_key,
        "max_tokens": max_tokens,
        # litellm-level retries for API errors (429/5xx) on top of our empty-retry.
        "num_retries": api_retries,
    }

    # reasoning_effort is only valid for the reasoning "mini" models, and Grok
    # accepts only "low"/"high" there. Keeping it low avoids burning the whole
    # token budget on hidden reasoning (a common cause of empty content).
    reasoning = os.environ.get("REASONING_EFFORT", "low").lower()
    if "mini" in model and reasoning in {"low", "high"}:
        kwargs["reasoning_effort"] = reasoning

    # Non-reasoning fallback for the rare case Grok keeps returning empty content.
    # Skipped if the primary model is already non-reasoning (avoids a pointless
    # duplicate) or explicitly disabled via FALLBACK_MODEL=none.
    fallback_llm: LLM | None = None
    fallback_model = os.environ.get("FALLBACK_MODEL", "xai/grok-3").strip()
    if fallback_model.lower() not in {"none", "", model.lower()} and "mini" in model:
        fallback_llm = LLM(
            model=fallback_model,
            temperature=temperature,
            api_key=api_key,
            max_tokens=max_tokens,
            num_retries=api_retries,
        )

    return ResilientGrokLLM(
        max_empty_retries=empty_retries,
        retry_delay=retry_delay,
        fallback_llm=fallback_llm,
        **kwargs,
    )

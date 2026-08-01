import json
from typing import Optional

import httpx

from app.config import Settings, get_settings
from app.services.grok_usage import GrokChatResult, GrokUsage
from app.services.http_client import request_with_retries


class AIServiceError(Exception):
    def __init__(self, detail: str, status_code: int = 503) -> None:
        super().__init__(detail)
        self.detail = detail
        self.status_code = status_code


class AIService:
    max_prompt_characters = 30000

    def __init__(self, settings: Optional[Settings] = None) -> None:
        self.settings = settings or get_settings()

    async def generate_response(
        self,
        messages: list[dict],
        model_override: Optional[str] = None,
        max_tokens: Optional[int] = None,
        max_prompt_characters: Optional[int] = None,
        tools: Optional[list[dict]] = None,
    ) -> GrokChatResult:
        prompt_messages = self._validated_prompt_messages(
            messages,
            model_override=model_override,
            max_prompt_characters=max_prompt_characters,
        )

        payload = self._payload(
            messages=prompt_messages,
            stream=False,
            model_override=model_override,
            max_tokens=max_tokens,
            tools=tools,
        )

        try:
            response = await request_with_retries(
                "POST",
                self.settings.grok_chat_url,
                headers={
                    "Authorization": f"Bearer {self.settings.grok_api_key}",
                    "Content-Type": "application/json",
                },
                json=payload,
                timeout=self.settings.grok_timeout_seconds,
            )
            response.raise_for_status()

            data = json.loads(response.text)
            text, tool_calls, finish_reason = self._parse_grok_choice(data)
            return GrokChatResult(
                text=text,
                usage=GrokUsage.from_api_payload(data),
                tool_calls=tool_calls,
                finish_reason=finish_reason,
            )
        except httpx.HTTPStatusError as error:
            raise self._http_status_error(error.response) from error
        except (httpx.RequestError, TimeoutError) as error:
            raise AIServiceError("Cannot reach Grok API right now.") from error
        except json.JSONDecodeError as error:
            raise AIServiceError(
                "Grok API returned an unreadable response.",
                status_code=500,
            ) from error

    def _validated_prompt_messages(
        self,
        messages: list[dict],
        model_override: Optional[str] = None,
        max_prompt_characters: Optional[int] = None,
    ) -> list[dict]:
        if not self.settings.grok_api_key:
            raise AIServiceError("Grok API key is not configured.", status_code=503)
        if not self._model_for_request(model_override):
            raise AIServiceError("Grok model is not configured.", status_code=503)

        prompt_messages = self._prompt_messages(messages)
        prompt_limit = max_prompt_characters or self.max_prompt_characters
        if self._prompt_length(prompt_messages) > prompt_limit:
            raise AIServiceError(
                "Message context is too large. Shorten the file or start a new chat.",
                status_code=400,
            )

        return prompt_messages

    def _payload(
        self,
        *,
        messages: list[dict],
        stream: bool,
        model_override: Optional[str] = None,
        max_tokens: Optional[int] = None,
        tools: Optional[list[dict]] = None,
    ) -> dict:
        payload = {
            "model": self._model_for_request(model_override),
            "messages": messages,
            "stream": stream,
        }
        if stream:
            payload["stream_options"] = {"include_usage": True}
        if max_tokens is not None:
            payload["max_tokens"] = max_tokens
        if tools:
            payload["tools"] = tools
            payload["tool_choice"] = "auto"
        return payload

    def _model_for_request(self, model_override: Optional[str] = None) -> Optional[str]:
        if model_override and model_override.strip():
            return model_override.strip()
        return self.settings.grok_model

    def _prompt_messages(self, messages: list[dict]) -> list[dict]:
        return [
            {"role": message["role"], "content": self._prompt_content(message)}
            for message in messages
        ]

    def _prompt_length(self, messages: list[dict]) -> int:
        return sum(self._content_length(message.get("content")) for message in messages)

    def _prompt_content(self, message: dict):
        content = message.get("content")
        if isinstance(content, list):
            return [self._content_part(part) for part in content]
        return str(content)

    def _content_part(self, part):
        if not isinstance(part, dict):
            return {"type": "text", "text": str(part)}
        part_type = part.get("type")
        if part_type == "image_url":
            image_url = part.get("image_url")
            if isinstance(image_url, dict):
                return {"type": "image_url", "image_url": dict(image_url)}
            return {"type": "image_url", "image_url": {"url": str(image_url)}}
        if part_type == "text":
            return {"type": "text", "text": str(part.get("text", ""))}
        return {"type": "text", "text": str(part)}

    def _content_length(self, content) -> int:
        if isinstance(content, list):
            return sum(self._content_part_length(part) for part in content)
        return len(str(content))

    def _content_part_length(self, part) -> int:
        if not isinstance(part, dict):
            return len(str(part))
        if part.get("type") == "image_url":
            return 512
        if part.get("type") == "text":
            return len(str(part.get("text", "")))
        return len(str(part))

    def _parse_grok_choice(self, data: dict) -> tuple[str, tuple[dict, ...], str | None]:
        """Reply text, tool calls, and why the model stopped."""
        choices = data.get("choices", [])
        if not choices:
            raise AIServiceError("Grok API returned no response.", status_code=502)

        choice = choices[0]
        message = choice.get("message", {})
        content = message.get("content", "")
        raw_calls = message.get("tool_calls")
        tool_calls: tuple[dict, ...] = ()
        if isinstance(raw_calls, list):
            tool_calls = tuple(call for call in raw_calls if isinstance(call, dict))
        finish_reason = choice.get("finish_reason")
        return (
            str(content or "").strip(),
            tool_calls,
            str(finish_reason) if finish_reason else None,
        )

    def _http_status_error(self, response: httpx.Response) -> AIServiceError:
        detail = self._grok_error_detail(response)
        if response.status_code == 429:
            return AIServiceError(
                detail or "Grok is at capacity right now. Try again in a few minutes.",
                status_code=503,
            )
        if response.status_code == 400:
            return AIServiceError(
                detail or "Grok rejected the request configuration.",
                status_code=502,
            )
        if response.status_code in {401, 403}:
            return AIServiceError(
                detail or "Grok API authentication failed. Check the API key.",
                status_code=503,
            )
        return AIServiceError(
            detail or "Grok API returned an error.",
            status_code=503,
        )

    def _grok_error_detail(self, response: httpx.Response) -> str:
        try:
            data = response.json()
        except json.JSONDecodeError:
            return response.text.strip()

        if not isinstance(data, dict):
            return response.text.strip()

        for key in ("error", "detail", "message"):
            value = data.get(key)
            if isinstance(value, str) and value.strip():
                return value.strip()
            if isinstance(value, dict):
                nested_message = value.get("message") or value.get("detail")
                if isinstance(nested_message, str) and nested_message.strip():
                    return nested_message.strip()

        return response.text.strip()

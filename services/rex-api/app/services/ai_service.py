import json
from collections.abc import AsyncIterator
from typing import Optional

import httpx

from app.config import Settings, get_settings
from app.services.grok_usage import GrokChatResult, GrokUsage, GrokUsageHolder
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
            return GrokChatResult(
                text=self._parse_grok_response(data),
                usage=GrokUsage.from_api_payload(data),
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

    async def stream_response(
        self,
        messages: list[dict],
        max_tokens: Optional[int] = None,
        model_override: Optional[str] = None,
        max_prompt_characters: Optional[int] = None,
        usage_holder: GrokUsageHolder | None = None,
    ) -> AsyncIterator[str]:
        prompt_messages = self._validated_prompt_messages(
            messages,
            model_override=model_override,
            max_prompt_characters=max_prompt_characters,
        )
        payload = self._payload(
            messages=prompt_messages,
            stream=True,
            model_override=model_override,
            max_tokens=max_tokens,
        )

        try:
            from app.services.http_client import get_http_client

            client = get_http_client()
            async with client.stream(
                "POST",
                self.settings.grok_chat_url,
                headers={
                    "Authorization": f"Bearer {self.settings.grok_api_key}",
                    "Content-Type": "application/json",
                },
                json=payload,
                timeout=self.settings.grok_timeout_seconds,
            ) as response:
                response.raise_for_status()
                captured_usage: GrokUsage | None = None
                async for token, chunk_usage in self._parse_grok_stream(response):
                    if chunk_usage is not None:
                        captured_usage = chunk_usage
                    if token:
                        yield token
                if usage_holder is not None:
                    usage_holder.usage = captured_usage
        except httpx.HTTPStatusError as error:
            raise self._http_status_error(error.response) from error
        except (httpx.RequestError, TimeoutError) as error:
            raise AIServiceError("Cannot reach Grok API right now.") from error
        except json.JSONDecodeError as error:
            raise AIServiceError(
                "Grok API returned an unreadable streaming response.",
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

    def _parse_grok_response(self, data: dict) -> str:
        choices = data.get("choices", [])
        if not choices:
            raise AIServiceError("Grok API returned no response.", status_code=502)

        message = choices[0].get("message", {})
        content = message.get("content", "")
        return str(content).strip()

    async def _parse_grok_stream(
        self,
        response: httpx.Response,
    ) -> AsyncIterator[tuple[str, GrokUsage | None]]:
        async for line in response.aiter_lines():
            line = line.strip()
            if not line or line.startswith(":"):
                continue
            if line.startswith("data:"):
                line = line[5:].strip()
            if line == "[DONE]":
                break

            data = json.loads(line)
            usage = GrokUsage.from_api_payload(data)
            token = ""
            choices = data.get("choices", [])
            if choices:
                delta = choices[0].get("delta", {})
                content = delta.get("content")
                if content:
                    token = str(content)
            if token or usage is not None:
                yield token, usage

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

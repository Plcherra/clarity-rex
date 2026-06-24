import hashlib
import json
from typing import Optional

import httpx

from app.config import Settings, get_settings
from app.services.ai_service import AIServiceError
from app.services.http_client import request_with_retries


class ChatEmbeddingService:
    def __init__(self, settings: Optional[Settings] = None) -> None:
        self.settings = settings or get_settings()

    @property
    def is_configured(self) -> bool:
        return bool(self.settings.grok_api_key and self.settings.grok_embedding_model)

    @property
    def model(self) -> str:
        return str(self.settings.grok_embedding_model or "").strip()

    async def embed_query(self, text: str) -> Optional[list[float]]:
        return await self.embed_text(text)

    async def embed_text(self, text: str) -> Optional[list[float]]:
        content = str(text or "").strip()
        if not content or not self.is_configured:
            return None

        payload = {
            "model": self.model,
            "input": content,
        }
        try:
            response = await request_with_retries(
                "POST",
                self.settings.grok_embeddings_url,
                headers={
                    "Authorization": f"Bearer {self.settings.grok_api_key}",
                    "Content-Type": "application/json",
                },
                json=payload,
                timeout=self.settings.grok_timeout_seconds,
            )
            response.raise_for_status()
            data = response.json()
        except httpx.HTTPStatusError as error:
            raise AIServiceError("Embedding API returned an error.") from error
        except (httpx.RequestError, TimeoutError) as error:
            raise AIServiceError("Cannot reach embedding API right now.") from error
        except json.JSONDecodeError as error:
            raise AIServiceError(
                "Embedding API returned an unreadable response.",
                status_code=500,
            ) from error

        embedding = self._first_embedding(data)
        if embedding is None:
            raise AIServiceError("Embedding API returned no embedding.", status_code=500)
        expected_dimensions = int(self.settings.grok_embedding_dimensions or 0)
        if expected_dimensions and len(embedding) != expected_dimensions:
            raise AIServiceError(
                "Embedding API returned an unexpected vector size.",
                status_code=500,
            )
        return embedding

    def content_hash(self, content: str) -> str:
        normalized = " ".join(str(content or "").split())
        return hashlib.sha256(normalized.encode("utf-8")).hexdigest()

    def embedding_record(
        self,
        *,
        conversation_id: str,
        content: str,
        embedding: list[float],
        source_kind: str = "message",
        message_id: Optional[str] = None,
    ) -> dict:
        return {
            "conversation_id": conversation_id,
            "message_id": message_id,
            "source_kind": source_kind,
            "content": content,
            "content_hash": self.content_hash(content),
            "embedding_model": self.model,
            "embedding": embedding,
        }

    def _first_embedding(self, data: object) -> Optional[list[float]]:
        if not isinstance(data, dict):
            return None
        rows = data.get("data")
        if not isinstance(rows, list) or not rows:
            return None
        first = rows[0]
        if not isinstance(first, dict):
            return None
        embedding = first.get("embedding")
        if not isinstance(embedding, list):
            return None
        return [float(value) for value in embedding]

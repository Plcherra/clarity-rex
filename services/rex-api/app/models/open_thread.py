from typing import Any, Literal, Optional

from pydantic import BaseModel, Field


OpenThreadStatus = Literal["active", "paused", "closed"]
OpenThreadSource = Literal["user_confirmed", "user_created"]

MAX_ACTIVE_OPEN_THREADS = 5


class OpenThreadCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    summary: Optional[str] = Field(default=None, max_length=500)
    status: OpenThreadStatus = "active"
    source: OpenThreadSource = "user_created"
    source_conversation_id: Optional[str] = None
    source_message_id: Optional[str] = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class OpenThreadUpdateRequest(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=200)
    summary: Optional[str] = Field(default=None, max_length=500)
    status: Optional[OpenThreadStatus] = None
    last_mentioned_at: Optional[str] = None
    last_follow_up_at: Optional[str] = None
    metadata: Optional[dict[str, Any]] = None


class OpenThreadResponse(BaseModel):
    id: str
    title: str
    summary: Optional[str] = None
    status: OpenThreadStatus
    source: OpenThreadSource
    source_conversation_id: Optional[str] = None
    source_message_id: Optional[str] = None
    last_mentioned_at: Optional[str] = None
    last_follow_up_at: Optional[str] = None
    metadata: dict[str, Any] = Field(default_factory=dict)
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

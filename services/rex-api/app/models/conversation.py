from typing import Optional

from pydantic import BaseModel, Field


class MessageResponse(BaseModel):
    id: str
    conversation_id: str
    role: str
    content: str
    timestamp: Optional[str] = None


class ConversationResponse(BaseModel):
    id: str
    title: Optional[str] = None
    timestamp: Optional[str] = None
    last_message: Optional[MessageResponse] = None


class ConversationTitleUpdateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=120)


class ConversationSearchResultResponse(BaseModel):
    conversation_id: str
    conversation_title: Optional[str] = None
    conversation_timestamp: Optional[str] = None
    message: Optional[MessageResponse] = None
    match_type: str
    preview: str
    relevance_score: Optional[float] = None
    search_reason: Optional[str] = None
    matched_terms: list[str] = Field(default_factory=list)

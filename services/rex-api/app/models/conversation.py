from typing import Optional

from pydantic import BaseModel


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


class ConversationSearchResultResponse(BaseModel):
    conversation_id: str
    conversation_title: Optional[str] = None
    conversation_timestamp: Optional[str] = None
    message: Optional[MessageResponse] = None
    match_type: str
    preview: str

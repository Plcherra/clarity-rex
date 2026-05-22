from typing import Any

from pydantic import BaseModel, Field


class ClarityActionRequest(BaseModel):
    action: str = Field(min_length=1)
    payload: dict[str, Any] = Field(default_factory=dict)
    confirmed: bool = False


class ClarityActionResponse(BaseModel):
    action: str
    status: str
    result: list[dict[str, Any]]

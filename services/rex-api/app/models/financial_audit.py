from pydantic import BaseModel, Field


class FinancialAuditEventRequest(BaseModel):
    event_type: str = Field(min_length=1)
    entity_type: str = Field(min_length=1)
    entity_id: str | None = None
    source: str = "app"
    previous_value: dict = Field(default_factory=dict)
    new_value: dict = Field(default_factory=dict)
    metadata: dict = Field(default_factory=dict)


class FinancialAuditEventResponse(BaseModel):
    status: str = "recorded"

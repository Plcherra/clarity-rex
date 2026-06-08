from __future__ import annotations

from typing import Any, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, Header, HTTPException
from pydantic import BaseModel

from app.dependencies import get_plaid_webhook_service
from app.services.plaid_webhook_service import (
    PlaidWebhookService,
    PlaidWebhookValidationError,
)

router = APIRouter(prefix="/plaid", tags=["plaid"])


class PlaidWebhookResponse(BaseModel):
    received: bool


@router.post("/webhook", response_model=PlaidWebhookResponse)
async def plaid_webhook(
    payload: dict[str, Any],
    background_tasks: BackgroundTasks,
    plaid_verification: Optional[str] = Header(default=None, alias="Plaid-Verification"),
    plaid_webhook_service: PlaidWebhookService = Depends(get_plaid_webhook_service),
) -> PlaidWebhookResponse:
    try:
        plaid_webhook_service.verify_webhook_request(
            payload=payload,
            plaid_verification=plaid_verification,
        )
    except PlaidWebhookValidationError as error:
        raise HTTPException(status_code=error.status_code, detail=error.detail) from error

    background_tasks.add_task(plaid_webhook_service.process_webhook, payload=payload)
    return PlaidWebhookResponse(received=True)

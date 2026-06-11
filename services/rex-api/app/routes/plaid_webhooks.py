from __future__ import annotations

import json
from typing import Any, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, Header, HTTPException, Request
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
    request: Request,
    background_tasks: BackgroundTasks,
    plaid_verification: Optional[str] = Header(default=None, alias="Plaid-Verification"),
    plaid_webhook_service: PlaidWebhookService = Depends(get_plaid_webhook_service),
) -> PlaidWebhookResponse:
    raw_body = await request.body()
    try:
        payload = json.loads(raw_body)
    except json.JSONDecodeError as error:
        raise HTTPException(
            status_code=400,
            detail="Invalid Plaid webhook payload.",
        ) from error
    if not isinstance(payload, dict):
        raise HTTPException(status_code=400, detail="Invalid Plaid webhook payload.")

    try:
        await plaid_webhook_service.verify_webhook_request(
            payload=payload,
            plaid_verification=plaid_verification,
            raw_body=raw_body,
        )
    except PlaidWebhookValidationError as error:
        raise HTTPException(status_code=error.status_code, detail=error.detail) from error

    background_tasks.add_task(plaid_webhook_service.process_webhook, payload=payload)
    return PlaidWebhookResponse(received=True)

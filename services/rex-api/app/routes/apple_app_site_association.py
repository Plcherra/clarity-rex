from __future__ import annotations

from fastapi import APIRouter
from fastapi.responses import JSONResponse

APPLE_TEAM_ID = "7N42NS8B9B"
IOS_BUNDLE_ID = "app.goclarity.clarity"
PLAID_OAUTH_PATH = "/plaid/oauth"

router = APIRouter(tags=["mobile-links"])


@router.get("/.well-known/apple-app-site-association", include_in_schema=False)
@router.get("/apple-app-site-association", include_in_schema=False)
async def apple_app_site_association() -> JSONResponse:
    app_id = f"{APPLE_TEAM_ID}.{IOS_BUNDLE_ID}"
    return JSONResponse(
        media_type="application/json",
        content={
            "applinks": {
                "details": [
                    {
                        "appIDs": [app_id],
                        "components": [
                            {
                                "/": PLAID_OAUTH_PATH,
                                "comment": "Plaid OAuth redirect for Clarity iOS.",
                            },
                            {
                                "/": f"{PLAID_OAUTH_PATH}/*",
                                "comment": "Plaid OAuth redirect children for Clarity iOS.",
                            },
                        ],
                    }
                ]
            }
        },
    )

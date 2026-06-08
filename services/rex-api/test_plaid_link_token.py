from __future__ import annotations

import asyncio
import os

from app.services.plaid_api_client import (
    PlaidApiClient,
    PlaidApiClientError,
    PlaidLinkTokenPayload,
)
from app.services.plaid_config import get_plaid_config_status


async def main() -> int:
    status = get_plaid_config_status()
    print(f"Plaid environment: {status.environment}")
    print(f"Plaid products: {', '.join(status.products) or 'unset'}")
    print(f"Plaid country codes: {', '.join(status.country_codes) or 'unset'}")

    if not status.configured:
        problems = [*status.missing, *status.invalid]
        print("Plaid is not configured: " + ", ".join(problems))
        return 2

    user_id = os.environ.get("PLAID_TEST_USER_ID", "production-link-token-smoke-user")
    client = PlaidApiClient()

    try:
        payload = PlaidLinkTokenPayload(user_id=user_id)
        response = await client.create_link_token(payload)
    except PlaidApiClientError as error:
        print(f"Plaid request failed: {error.detail}")
        if error.plaid_error_code:
            print(f"Plaid error code: {error.plaid_error_code}")
        if error.request_id:
            print(f"Plaid request id: {error.request_id}")
        return 1

    link_token = response.get("link_token")
    expiration = response.get("expiration")
    if not isinstance(link_token, str) or not link_token:
        print("Plaid did not return a link token.")
        return 1

    print("\nLink token:")
    print(link_token)
    if expiration:
        print(f"\nExpiration: {expiration}")
    print("\nThis is a short-lived Link token, not an access token.")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))

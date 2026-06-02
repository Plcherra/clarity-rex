from dataclasses import dataclass
from typing import Optional

import httpx
from fastapi import Depends, HTTPException, WebSocket, status
from starlette.requests import HTTPConnection

from app.config import Settings, get_settings
from app.services.http_client import request_with_retries


@dataclass(frozen=True)
class AuthenticatedUser:
    id: str
    email: Optional[str]
    access_token: str


async def get_current_user(
    connection: HTTPConnection,
    settings: Settings = Depends(get_settings),
) -> AuthenticatedUser:
    token = _authorization_header_token(connection.headers.get("authorization"))
    if token is None:
        token = connection.query_params.get("access_token")

    return await authenticate_access_token(token, settings=settings)


async def authenticate_websocket(
    websocket: WebSocket,
    settings: Optional[Settings] = None,
) -> AuthenticatedUser:
    token = _authorization_header_token(websocket.headers.get("authorization"))
    return await authenticate_access_token(token, settings=settings or get_settings())


async def authenticate_access_token(
    token: Optional[str],
    settings: Settings,
) -> AuthenticatedUser:
    if not _supabase_auth_configured(settings):
        if settings.app_environment == "production":
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Supabase auth is not configured.",
            )
        return AuthenticatedUser(
            id="00000000-0000-0000-0000-000000000000",
            email=None,
            access_token="development-token",
        )

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Supabase access token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = await _fetch_supabase_user(token, settings)
    user_id = str(user.get("id") or user.get("sub") or "").strip()
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Supabase access token did not include a user id.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    email = user.get("email")
    return AuthenticatedUser(
        id=user_id,
        email=email if isinstance(email, str) else None,
        access_token=token,
    )


async def _fetch_supabase_user(token: str, settings: Settings) -> dict:
    assert settings.supabase_url is not None
    api_key = settings.supabase_anon_key or settings.supabase_service_role_key
    assert api_key is not None

    url = f"{settings.supabase_url.rstrip('/')}/auth/v1/user"
    headers = {
        "apikey": api_key,
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    }

    try:
        response = await request_with_retries("GET", url, headers=headers)
        response.raise_for_status()
        payload = response.json()
    except httpx.HTTPStatusError as error:
        status_code = error.response.status_code
        if status_code in {401, 403}:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired Supabase access token.",
                headers={"WWW-Authenticate": "Bearer"},
            ) from error
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Supabase auth returned an error.",
        ) from error
    except (httpx.RequestError, TimeoutError, ValueError) as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Cannot validate Supabase access token.",
        ) from error

    if not isinstance(payload, dict):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Supabase auth returned an unreadable user response.",
        )
    return payload


def _authorization_header_token(value: Optional[str]) -> Optional[str]:
    if not value:
        return None
    scheme, _, token = value.partition(" ")
    if scheme.lower() != "bearer":
        return None
    token = token.strip()
    return token or None


def _supabase_auth_configured(settings: Settings) -> bool:
    return bool(
        settings.supabase_url
        and (settings.supabase_anon_key or settings.supabase_service_role_key)
    )

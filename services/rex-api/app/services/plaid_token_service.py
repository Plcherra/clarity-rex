from __future__ import annotations

import base64
import hashlib
from typing import Optional

from cryptography.fernet import Fernet

from app.config import Settings, get_settings
from app.services.plaid_sync_models import PlaidSyncServiceError


class PlaidTokenService:
    def __init__(self, settings: Optional[Settings] = None) -> None:
        self.settings = settings or get_settings()

    def encrypted_access_token_ref(self, access_token: str) -> str:
        key = self._fernet_key()
        encrypted = Fernet(key).encrypt(access_token.encode()).decode()
        return f"fernet:v1:{encrypted}"

    def decrypt_access_token_ref(self, access_token_ref: str) -> str:
        encrypted_token = access_token_ref.removeprefix("fernet:v1:")
        if encrypted_token == access_token_ref:
            raise PlaidSyncServiceError("Plaid token reference is invalid.")

        try:
            return Fernet(self._fernet_key()).decrypt(encrypted_token.encode()).decode()
        except Exception as error:
            raise PlaidSyncServiceError("Plaid token reference is unreadable.") from error

    def _fernet_key(self) -> bytes:
        secret = (
            self.settings.plaid_token_encryption_secret
            or self.settings.plaid_secret
            or ""
        ).strip()
        if not secret:
            raise PlaidSyncServiceError("Plaid token encryption is not configured.")
        return base64.urlsafe_b64encode(hashlib.sha256(secret.encode()).digest())

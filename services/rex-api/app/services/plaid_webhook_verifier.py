from __future__ import annotations

import base64
import hashlib
import json
import time
from dataclasses import dataclass
from typing import Any

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import encode_dss_signature

from app.services.plaid_api_client import PlaidApiClient, PlaidApiClientError


class PlaidWebhookVerificationError(Exception):
    pass


@dataclass(frozen=True)
class PlaidWebhookJwt:
    header: dict[str, Any]
    claims: dict[str, Any]
    signing_input: bytes
    signature: bytes


class PlaidWebhookVerifier:
    max_token_age_seconds = 5 * 60

    def __init__(
        self,
        *,
        plaid_client: PlaidApiClient,
        now: Any = time.time,
    ) -> None:
        self.plaid_client = plaid_client
        self._now = now

    async def verify(self, *, plaid_verification: str | None, raw_body: bytes) -> None:
        token = (plaid_verification or "").strip()
        if not token:
            raise PlaidWebhookVerificationError("Missing Plaid verification header.")

        parsed = self._parse_jwt(token)
        key_id = _required_string(parsed.header, "kid")
        if _required_string(parsed.header, "alg") != "ES256":
            raise PlaidWebhookVerificationError("Unsupported Plaid verification JWT.")

        key_response = await self.plaid_client.get_webhook_verification_key(key_id)
        public_key = self._public_key_from_response(key_response, expected_key_id=key_id)
        self._verify_signature(public_key=public_key, parsed=parsed)
        self._verify_freshness(parsed.claims)
        self._verify_body_hash(claims=parsed.claims, raw_body=raw_body)

    def _parse_jwt(self, token: str) -> PlaidWebhookJwt:
        parts = token.split(".")
        if len(parts) != 3:
            raise PlaidWebhookVerificationError("Invalid Plaid verification JWT.")

        try:
            header = _json_part(parts[0])
            claims = _json_part(parts[1])
            signature = _b64url_decode(parts[2])
        except (ValueError, json.JSONDecodeError) as error:
            raise PlaidWebhookVerificationError(
                "Invalid Plaid verification JWT.",
            ) from error

        if not isinstance(header, dict) or not isinstance(claims, dict):
            raise PlaidWebhookVerificationError("Invalid Plaid verification JWT.")

        return PlaidWebhookJwt(
            header=header,
            claims=claims,
            signing_input=f"{parts[0]}.{parts[1]}".encode("ascii"),
            signature=signature,
        )

    def _public_key_from_response(
        self,
        response: dict[str, Any],
        *,
        expected_key_id: str,
    ) -> ec.EllipticCurvePublicKey:
        key = response.get("key")
        if not isinstance(key, dict):
            key = response

        if _required_string(key, "kid") != expected_key_id:
            raise PlaidWebhookVerificationError("Plaid verification key mismatch.")
        if _required_string(key, "kty") != "EC" or _required_string(key, "crv") != "P-256":
            raise PlaidWebhookVerificationError("Unsupported Plaid verification key.")

        expired_at = key.get("expired_at")
        if expired_at is not None:
            try:
                expired_at_seconds = float(expired_at)
            except (TypeError, ValueError) as error:
                raise PlaidWebhookVerificationError(
                    "Invalid Plaid verification key.",
                ) from error
            if expired_at_seconds <= float(self._now()):
                raise PlaidWebhookVerificationError("Expired Plaid verification key.")

        x = int.from_bytes(_b64url_decode(_required_string(key, "x")), "big")
        y = int.from_bytes(_b64url_decode(_required_string(key, "y")), "big")
        numbers = ec.EllipticCurvePublicNumbers(x, y, ec.SECP256R1())
        return numbers.public_key()

    def _verify_signature(
        self,
        *,
        public_key: ec.EllipticCurvePublicKey,
        parsed: PlaidWebhookJwt,
    ) -> None:
        if len(parsed.signature) != 64:
            raise PlaidWebhookVerificationError("Invalid Plaid verification signature.")
        r = int.from_bytes(parsed.signature[:32], "big")
        s = int.from_bytes(parsed.signature[32:], "big")
        signature = encode_dss_signature(r, s)
        try:
            public_key.verify(
                signature,
                parsed.signing_input,
                ec.ECDSA(hashes.SHA256()),
            )
        except InvalidSignature as error:
            raise PlaidWebhookVerificationError(
                "Invalid Plaid verification signature.",
            ) from error

    def _verify_freshness(self, claims: dict[str, Any]) -> None:
        try:
            issued_at = float(claims.get("iat"))
        except (TypeError, ValueError) as error:
            raise PlaidWebhookVerificationError(
                "Plaid verification iat is required.",
            ) from error
        now = float(self._now())
        if issued_at > now + 60:
            raise PlaidWebhookVerificationError("Plaid verification JWT is not valid yet.")
        if now - issued_at > self.max_token_age_seconds:
            raise PlaidWebhookVerificationError("Expired Plaid verification JWT.")

    def _verify_body_hash(self, *, claims: dict[str, Any], raw_body: bytes) -> None:
        expected_hash = _required_string(claims, "request_body_sha256")
        digest = hashlib.sha256(raw_body).digest()
        valid_hashes = {
            digest.hex(),
            base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii"),
        }
        if expected_hash not in valid_hashes:
            raise PlaidWebhookVerificationError("Plaid webhook body hash mismatch.")


def _json_part(value: str) -> dict[str, Any]:
    return json.loads(_b64url_decode(value).decode("utf-8"))


def _b64url_decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(f"{value}{padding}")


def _required_string(payload: dict[str, Any], key: str) -> str:
    value = payload.get(key)
    if not isinstance(value, str) or not value.strip():
        raise PlaidWebhookVerificationError(f"Plaid verification {key} is required.")
    return value.strip()

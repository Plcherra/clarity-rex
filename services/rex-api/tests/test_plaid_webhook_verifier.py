import base64
import hashlib
import json

import pytest
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

from app.services.plaid_webhook_verifier import (
    PlaidWebhookVerificationError,
    PlaidWebhookVerifier,
)


class FakePlaidClient:
    def __init__(self, key):
        self.key = key
        self.key_id = None

    async def get_webhook_verification_key(self, key_id):
        self.key_id = key_id
        return {"key": self.key}


def public_jwk(private_key, *, key_id="key-1", expired_at=None):
    numbers = private_key.public_key().public_numbers()
    key = {
        "kid": key_id,
        "kty": "EC",
        "crv": "P-256",
        "x": b64url(numbers.x.to_bytes(32, "big")),
        "y": b64url(numbers.y.to_bytes(32, "big")),
    }
    if expired_at is not None:
        key["expired_at"] = expired_at
    return key


def signed_plaid_verification(
    private_key,
    raw_body,
    *,
    key_id="key-1",
    issued_at=1_800_000_000,
    body_hash=None,
    alg="ES256",
):
    header = {"alg": alg, "kid": key_id}
    claims = {
        "iat": issued_at,
        "request_body_sha256": body_hash or hashlib.sha256(raw_body).hexdigest(),
    }
    signing_input = f"{json_part(header)}.{json_part(claims)}"
    der_signature = private_key.sign(
        signing_input.encode("ascii"),
        ec.ECDSA(hashlib_to_cryptography_sha256()),
    )
    r, s = decode_dss_signature(der_signature)
    signature = b64url(r.to_bytes(32, "big") + s.to_bytes(32, "big"))
    return f"{signing_input}.{signature}"


@pytest.mark.asyncio
async def test_verifier_accepts_valid_plaid_verification_jwt():
    private_key = ec.generate_private_key(ec.SECP256R1())
    raw_body = b'{"webhook_type":"TRANSACTIONS","webhook_code":"SYNC_UPDATES_AVAILABLE"}'
    plaid_client = FakePlaidClient(public_jwk(private_key))
    verifier = PlaidWebhookVerifier(plaid_client=plaid_client, now=lambda: 1_800_000_030)
    token = signed_plaid_verification(private_key, raw_body)

    await verifier.verify(plaid_verification=token, raw_body=raw_body)

    assert plaid_client.key_id == "key-1"


@pytest.mark.asyncio
async def test_verifier_rejects_body_hash_mismatch():
    private_key = ec.generate_private_key(ec.SECP256R1())
    plaid_client = FakePlaidClient(public_jwk(private_key))
    verifier = PlaidWebhookVerifier(plaid_client=plaid_client, now=lambda: 1_800_000_030)
    token = signed_plaid_verification(private_key, b'{"ok":true}')

    with pytest.raises(PlaidWebhookVerificationError, match="body hash"):
        await verifier.verify(plaid_verification=token, raw_body=b'{"ok":false}')


@pytest.mark.asyncio
async def test_verifier_rejects_expired_jwt():
    private_key = ec.generate_private_key(ec.SECP256R1())
    plaid_client = FakePlaidClient(public_jwk(private_key))
    verifier = PlaidWebhookVerifier(plaid_client=plaid_client, now=lambda: 1_800_001_000)
    token = signed_plaid_verification(private_key, b"{}", issued_at=1_800_000_000)

    with pytest.raises(PlaidWebhookVerificationError, match="Expired"):
        await verifier.verify(plaid_verification=token, raw_body=b"{}")


@pytest.mark.asyncio
async def test_verifier_rejects_bad_signature():
    private_key = ec.generate_private_key(ec.SECP256R1())
    wrong_key = ec.generate_private_key(ec.SECP256R1())
    plaid_client = FakePlaidClient(public_jwk(wrong_key))
    verifier = PlaidWebhookVerifier(plaid_client=plaid_client, now=lambda: 1_800_000_030)
    token = signed_plaid_verification(private_key, b"{}")

    with pytest.raises(PlaidWebhookVerificationError, match="signature"):
        await verifier.verify(plaid_verification=token, raw_body=b"{}")


@pytest.mark.asyncio
async def test_verifier_rejects_missing_header():
    private_key = ec.generate_private_key(ec.SECP256R1())
    plaid_client = FakePlaidClient(public_jwk(private_key))
    verifier = PlaidWebhookVerifier(plaid_client=plaid_client)

    with pytest.raises(PlaidWebhookVerificationError, match="Missing"):
        await verifier.verify(plaid_verification=None, raw_body=b"{}")


def json_part(payload):
    return b64url(json.dumps(payload, separators=(",", ":")).encode("utf-8"))


def b64url(value):
    raw = value if isinstance(value, bytes) else value.encode("utf-8")
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def hashlib_to_cryptography_sha256():
    from cryptography.hazmat.primitives import hashes

    return hashes.SHA256()

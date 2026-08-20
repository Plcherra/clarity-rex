from app.services.plaid_account_identity import (
    plaid_account_identity,
    transaction_fingerprint,
)


def test_identity_matches_same_account_across_relink_ids():
    first = plaid_account_identity(
        institution_name="Capital One",
        mask="1410",
        account_type="credit",
        account_subtype="credit card",
    )
    second = plaid_account_identity(
        institution_name=" capital  one ",
        mask="1410",
        account_type="credit",
        account_subtype="credit card",
    )
    assert first == second
    assert first is not None


def test_identity_requires_institution_and_mask():
    assert (
        plaid_account_identity(
            institution_name=None,
            mask="1410",
            account_type="credit",
            account_subtype="credit card",
        )
        is None
    )
    assert (
        plaid_account_identity(
            institution_name="Capital One",
            mask=None,
            account_type="credit",
            account_subtype="credit card",
        )
        is None
    )


def test_identity_treats_different_masks_as_different_accounts():
    checking = plaid_account_identity(
        institution_name="Capital One",
        mask="3279",
        account_type="depository",
        account_subtype="checking",
    )
    other_checking = plaid_account_identity(
        institution_name="Capital One",
        mask="1217",
        account_type="depository",
        account_subtype="checking",
    )
    assert checking != other_checking


def test_transaction_fingerprint_ignores_plaid_ids():
    left = transaction_fingerprint(
        {
            "date": "2026-08-01",
            "amount": "12.50",
            "merchant": "Coffee",
            "type": "expense",
            "pending": False,
        }
    )
    right = transaction_fingerprint(
        {
            "date": "2026-08-01",
            "amount": "12.50",
            "description": "Coffee",
            "type": "expense",
            "pending": False,
            "plaid_transaction_id": "other-id",
        }
    )
    assert left == right

from app.services.plaid_liability_balances import (
    apply_credit_liability_patch,
    credit_balance_patches_from_liabilities,
)


def test_liabilities_fill_missing_credit_leftover_and_limit():
    patches = credit_balance_patches_from_liabilities(
        {
            "accounts": [
                {
                    "account_id": "cap-card",
                    "type": "credit",
                    "balances": {
                        "current": 270.68,
                        "available": 608.08,
                        "limit": 878.76,
                    },
                }
            ],
            "liabilities": {
                "credit": [
                    {
                        "account_id": "cap-card",
                        "available_credit": 608.08,
                    }
                ]
            },
        }
    )

    merged = apply_credit_liability_patch(
        {
            "account_id": "cap-card",
            "type": "credit",
            "balances": {
                "current": 270.68,
                "available": None,
                "limit": None,
            },
        },
        patches["cap-card"],
    )

    assert merged["balances"]["current"] == 270.68
    assert merged["balances"]["available"] == 608.08
    assert merged["balances"]["limit"] == 878.76


def test_liability_patch_does_not_overwrite_existing_available():
    merged = apply_credit_liability_patch(
        {
            "account_id": "boa-card",
            "balances": {"current": 0, "available": 500.0},
        },
        {"available": 1.0, "limit": 500.0},
    )

    assert merged["balances"]["available"] == 500.0
    assert merged["balances"]["limit"] == 500.0


def test_liabilities_parse_string_limit_values():
    patches = credit_balance_patches_from_liabilities(
        {
            "accounts": [
                {
                    "account_id": "cap-card",
                    "type": "credit",
                    "balances": {"current": "464.38", "available": None, "limit": None},
                }
            ],
            "liabilities": {
                "credit": [
                    {
                        "account_id": "cap-card",
                        "available_credit": "435.62",
                        "credit_limit": "900.00",
                    }
                ]
            },
        }
    )

    assert patches["cap-card"]["available"] == 435.62
    assert patches["cap-card"]["limit"] == 900.0


def test_liabilities_ignore_depository_accounts():
    patches = credit_balance_patches_from_liabilities(
        {
            "accounts": [
                {
                    "account_id": "checking",
                    "type": "depository",
                    "balances": {"available": 66.15, "current": 89.66},
                }
            ],
            "liabilities": {"credit": []},
        }
    )

    assert patches == {}

import pytest

from app.services.plaid_category_mapper import clarity_category_for_plaid_transaction


@pytest.mark.parametrize(
    ("transaction", "expected"),
    [
        ({"name": "Monthly Interest Paid", "amount": -0.02}, "Income / Interest"),
        ({"name": "INTEREST CHARGE PURCHASES", "amount": 9.99}, "Fees & Interest"),
        ({"name": "CURSOR AI-POWERED IDE", "amount": 20.0}, "Subscriptions"),
        ({"name": "HETZNER ONLINE", "amount": 8.21}, "Subscriptions"),
        ({"name": "11LABS.IO", "amount": 5.0}, "Subscriptions"),
        ({"name": "GOG.COM Warsaw", "amount": 15.93}, "Shopping"),
        ({"name": "AMC 9640 ONLINE", "amount": 2.99}, "Entertainment"),
        (
            {"name": "OVERDRAFT PROTECTION TO 466004495080", "amount": 4.55},
            "Transfer Out",
        ),
        ({"name": "TST* BOM DOUGH - ONE CANA", "amount": 4.25}, "Coffee / Quick Food"),
    ],
)
def test_plaid_category_mapper_covers_real_device_uncategorized_rows(
    transaction,
    expected,
):
    assert clarity_category_for_plaid_transaction(transaction) == expected


@pytest.mark.parametrize(
    ("primary", "detailed", "expected"),
    [
        ("BANK_FEES", "BANK_FEES_OVERDRAFT_FEES", "Fees & Interest"),
        ("ENTERTAINMENT", "ENTERTAINMENT_TV_AND_MOVIES", "Entertainment"),
        ("TRANSFER_IN", "TRANSFER_IN_DEPOSIT", "Transfer In"),
    ],
)
def test_plaid_category_mapper_covers_more_personal_finance_categories(
    primary,
    detailed,
    expected,
):
    assert (
        clarity_category_for_plaid_transaction(
            {
                "name": "Plaid PFC Row",
                "amount": 10.0,
                "personal_finance_category": {
                    "primary": primary,
                    "detailed": detailed,
                },
            }
        )
        == expected
    )


def test_plaid_category_mapper_never_returns_empty_category_for_expense():
    assert (
        clarity_category_for_plaid_transaction(
            {
                "name": "UNKNOWN MERCHANT WITH NO PLAID CATEGORY",
                "amount": 12.34,
            }
        )
        == "Miscellaneous"
    )

from app.services.category_name_normalization import (
    categories_match,
    category_lookup_keys,
    category_match_key,
)
from app.services.capabilities.finance_context_lookup import find_category


def test_spoken_singular_matches_saved_plural_category():
    assert category_match_key("work reimbursement") == "work reimbursement"
    assert category_match_key("Work Reimbursements") == "work reimbursement"
    assert categories_match("work reimbursement", "Work Reimbursements")
    assert "work reimbursements" in category_lookup_keys("work reimbursement")


def test_find_category_resolves_singular_against_catalog():
    context = {
        "categories": [
            {
                "id": "cat-reimb",
                "name": "Work Reimbursements",
                "normalized_name": "work reimbursements",
            }
        ]
    }
    found = find_category(context, "work reimbursement")
    assert found is not None
    assert found["id"] == "cat-reimb"

from app.services.insight_generator import generate_dashboard_insights


def test_generate_dashboard_insights_from_financial_context():
    context = {
        "period": {"reference_month": "2026-07"},
        "cash_flow": {
            "income_this_month": 300.0,
            "spent_this_month": 500.0,
            "available_this_month": -200.0,
        },
        "biggest_month_over_month_increases": [
            {
                "category": "Dining",
                "spent_this_month": 120.0,
                "spent_last_month": 60.0,
                "percent_change": 1.0,
            }
        ],
        "budget": {
            "period_key": "2026-07",
            "top_overspending_categories": [
                {
                    "category": "Dining",
                    "budgeted": 100.0,
                    "spent": 150.0,
                    "overspent": 50.0,
                }
            ],
        },
    }

    items = generate_dashboard_insights(context)
    assert len(items) == 3
    assert {item.insight_type for item in items} == {
        "net_cash_flow",
        "mom_leak",
        "budget_overspend",
    }
    assert all(item.source == "dashboard_snapshot" for item in items)


def test_generate_dashboard_insights_empty_without_activity():
    items = generate_dashboard_insights(
        {
            "period": {"reference_month": "2026-07"},
            "cash_flow": {
                "income_this_month": 0,
                "spent_this_month": 0,
                "available_this_month": 0,
            },
            "budget": {"period_key": "2026-07", "top_overspending_categories": []},
        }
    )
    assert items == []

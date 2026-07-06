from datetime import datetime
from zoneinfo import ZoneInfo

from app.services.goal_command_formatting import date_from_text
from app.services.plan_merge_service import sanitize_plan_target_date


def _time_context():
    return {
        "date": datetime(2026, 6, 1, tzinfo=ZoneInfo("America/New_York")).date(),
    }


def test_date_from_text_does_not_treat_on_locked_as_due_date():
    text = (
        "Alright. So we agree on locked up on the go to buy dumbbells "
        "from maybe 40 to sixty pounds."
    )
    assert date_from_text(text, time_context=_time_context()) is None


def test_date_from_text_still_parses_real_due_dates():
    assert date_from_text(
        "Save $5000 by August",
        time_context=_time_context(),
    ) == "August"
    assert date_from_text(
        "Finish paperwork on June 18",
        time_context=_time_context(),
    ) == "June 18"


def test_sanitize_plan_target_date_drops_garbage():
    assert sanitize_plan_target_date("locked") is None
    assert sanitize_plan_target_date("June 18") == "June 18"
    assert sanitize_plan_target_date("2026-07-01") == "2026-07-01"

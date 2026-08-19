from app.services.usage_cost_breakdown import (
    attach_user_cost_insights,
    count_plaid_links,
    finalize_slices,
    group_events_by_user,
    largest_driver,
    merge_all_slices,
    plaid_platform_totals,
    pricing_from_cogs,
    slice_label_key,
    voice_cost_cents,
)


def test_slice_label_keys_match_live_providers():
    assert (
        slice_label_key(
            provider="grok",
            feature="assistant_response",
            channel="chat",
            event_type="llm",
        )
        == "grok_chat"
    )
    assert (
        slice_label_key(
            provider="grok",
            feature="assistant_response",
            channel="voice",
            event_type="llm",
        )
        == "grok_voice"
    )
    assert (
        slice_label_key(
            provider="google_tts",
            feature="text_to_speech",
            channel="voice",
            event_type="tts",
        )
        == "google_tts"
    )
    assert (
        slice_label_key(
            provider="deepgram",
            feature="speech_to_text",
            channel="voice",
            event_type="stt",
        )
        == "deepgram_stt"
    )
    assert (
        slice_label_key(
            provider="deepgram_tts",
            feature="text_to_speech",
            channel="voice",
            event_type="tts",
        )
        == "deepgram_tts"
    )
    assert (
        slice_label_key(
            provider="clarity_api",
            feature="voice_call",
            channel="voice",
            event_type="voice_session",
        )
        == "voice_session"
    )


def test_finalize_slices_ranks_google_tts_and_keeps_unmetered_session():
    grouped = group_events_by_user(
        [
            {
                "user_id": "u1",
                "provider": "google_tts",
                "feature": "text_to_speech",
                "channel": "voice",
                "event_type": "tts",
                "estimated_cost_cents": 140.688,
                "duration_ms": 1000,
                "unit_count": 10,
            },
            {
                "user_id": "u1",
                "provider": "grok",
                "feature": "assistant_response",
                "channel": "chat",
                "event_type": "llm",
                "estimated_cost_cents": 81.23,
                "unit_count": 100,
            },
            {
                "user_id": "u1",
                "provider": "clarity_api",
                "feature": "voice_call",
                "channel": "voice",
                "event_type": "voice_session",
                "estimated_cost_cents": 0,
                "duration_ms": 5000,
            },
        ]
    )
    slices = finalize_slices(merge_all_slices(grouped))
    assert slices[0]["label_key"] == "google_tts"
    assert slices[0]["share"] == 0.634
    assert slices[1]["label_key"] == "grok_chat"
    session = next(item for item in slices if item["label_key"] == "voice_session")
    assert session["metered"] is False
    assert session["share"] == 0
    driver = largest_driver(slices)
    assert driver is not None
    assert driver["label_key"] == "google_tts"


def test_pricing_helper_uses_cogs_and_excludes_plaid():
    slices = finalize_slices(
        merge_all_slices(
            group_events_by_user(
                [
                    {
                        "user_id": "u1",
                        "provider": "grok",
                        "feature": "assistant_response",
                        "channel": "voice",
                        "event_type": "llm",
                        "estimated_cost_cents": 50,
                    },
                    {
                        "user_id": "u1",
                        "provider": "deepgram",
                        "feature": "speech_to_text",
                        "channel": "voice",
                        "event_type": "stt",
                        "estimated_cost_cents": 10,
                    },
                ]
            )
        )
    )
    pricing = pricing_from_cogs(
        cogs_cents=60,
        active_user_count=1,
        voice_seconds=120,
        voice_cost_cents=voice_cost_cents(slices),
    )
    assert pricing["plaid_included"] is False
    assert pricing["cost_per_active_user_cents"] == 60
    assert pricing["voice_minutes"] == 2
    assert pricing["cost_per_voice_minute_cents"] == 30
    assert pricing["price_floor_2x_cents"] == 120
    assert pricing["price_floor_3x_cents"] == 180
    assert pricing["price_per_user_2x_cents"] == 120
    assert pricing["price_per_user_3x_cents"] == 180


def test_plaid_counts_are_not_turned_into_dollars():
    counts = count_plaid_links(
        [{"user_id": "u2"}, {"user_id": "u2"}, {"user_id": "u3"}],
        [{"user_id": "u2"}, {"user_id": "u3"}, {"user_id": "u3"}],
    )
    assert counts["u2"] == {"item_count": 2, "account_count": 1}
    platform = plaid_platform_totals(counts)
    assert platform == {
        "metered": False,
        "user_count": 2,
        "item_count": 3,
        "account_count": 3,
    }
    users = attach_user_cost_insights(
        [{"user_id": "u2", "month_estimated_cost_cents": 0}],
        grouped={},
        plaid_counts=counts,
    )
    assert users[0]["plaid_item_count"] == 2
    assert users[0]["plaid_account_count"] == 1
    assert users[0]["plaid_cost_metered"] is False
    assert users[0]["largest_cost_driver"] is None
    assert users[0]["cost_breakdown"] == []

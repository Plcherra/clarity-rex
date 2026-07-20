"""Counters and envelope shape for durable write memory_changes."""

from app.services.durable_write_proposal import DurableWriteProposal
from app.services.durable_write_results import applied_memory_changes


def test_open_thread_update_counts_as_updated_not_merged() -> None:
    proposal = DurableWriteProposal(
        write_kind="open_thread",
        title="Wake at 6am",
        body="Wake at 6am",
        apply_snapshot={
            "type": "open_thread_update",
            "payload": {
                "thread_id": "thread-1",
                "title": "Wake at 6am",
                "summary": "Wake at 6am",
            },
        },
    )
    changes = applied_memory_changes(
        proposal=proposal,
        record={"id": "thread-1", "title": "Wake at 6am"},
        merged=False,
        updated_count=1,
    )
    assert changes["created"] == 0
    assert changes["updated"] == 1
    assert changes["merged"] == 0
    assert changes["write_proposals"][0]["result"][0]["action"] == "direct_updated"

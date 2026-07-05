from app.services.durable_write_builders import proposal_from_open_thread
from app.services.durable_write_proposal import DurableWriteProposal, new_durable_write_proposal_id


def test_new_durable_write_proposal_ids_are_unique():
    first = new_durable_write_proposal_id()
    second = new_durable_write_proposal_id()
    assert first.startswith("write-")
    assert second.startswith("write-")
    assert first != second


def test_open_thread_proposal_gets_unique_id():
    proposal = proposal_from_open_thread(
        title="Follow up",
        summary="Stress at work",
        conversation_id="conversation-1",
        source_message_id="message-1",
    )
    assert proposal.proposal_id.startswith("write-")
    assert proposal.proposal_id != "write-1"


def test_default_proposal_factory_generates_unique_ids():
    first = DurableWriteProposal(write_kind="memory", title="A", body="B")
    second = DurableWriteProposal(write_kind="memory", title="A", body="B")
    assert first.proposal_id != second.proposal_id

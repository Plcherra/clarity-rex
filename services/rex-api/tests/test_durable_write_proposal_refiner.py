from app.services.durable_write_proposal import DurableWriteProposal
from app.services.durable_write_proposal_refiner import (
    DurableWriteProposalRefiner,
    needs_proposal_copy_refinement,
)


class _FakeAIService:
    def __init__(self, text: str) -> None:
        self.text = text
        self.calls = 0

    async def generate_response(self, messages, **kwargs):
        self.calls += 1

        class _Result:
            text = self.text

        return _Result()


def test_needs_refinement_for_rambling_voice_transcript() -> None:
    proposal = DurableWriteProposal(
        write_kind="memory",
        title="User has a gonna be around 40.",
        body="User has a gonna be around 40.",
    )
    assert needs_proposal_copy_refinement(proposal)


def test_skips_refinement_for_short_clean_memory() -> None:
    proposal = DurableWriteProposal(
        write_kind="memory",
        title="Pedro prefers tea",
        body="Pedro prefers tea over coffee.",
    )
    assert not needs_proposal_copy_refinement(proposal)


async def test_refiner_rewrites_title_and_body() -> None:
    ai = _FakeAIService(
        '{"title":"Buy adjustable dumbbells","body":"Pedro wants adjustable dumbbells around 35-65 lb for squats and upper-body training."}'
    )
    refiner = DurableWriteProposalRefiner(ai)
    proposal = DurableWriteProposal(
        write_kind="memory",
        title="User has a gonna be around 40.",
        body="User has a gonna be around 40.",
        apply_snapshot={
            "type": "memory",
            "payload": {
                "memory_type": "fact",
                "content": "User has a gonna be around 40.",
            },
        },
    )

    refined = await refiner.refine(
        proposal,
        conversation_messages=[
            {"role": "user", "content": "I want bowflex style dumbbells around 35 to 65 pounds."}
        ],
        user_message="save that",
    )

    assert ai.calls == 1
    assert refined.title == "Buy adjustable dumbbells"
    assert "35-65 lb" in refined.body
    assert refined.apply_snapshot["payload"]["content"] == refined.body

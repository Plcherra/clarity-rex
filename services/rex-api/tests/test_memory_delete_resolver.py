import pytest

from app.services.memory_delete_resolver import (
    COMMITMENT_DELETE_SCOPE,
    MemoryDeleteResolver,
    is_vague_delete_reference,
    parse_delete_request,
)


class FakeDeleteMemoryStore:
    def __init__(
        self,
        *,
        commitments: list[dict] | None = None,
        plans: list[dict] | None = None,
        memories: list[dict] | None = None,
    ) -> None:
        self.commitments = commitments or []
        self.plans = plans or []
        self.memories = memories or []

    async def list_commitments(self, **kwargs):
        return self.commitments

    async def list_plans(self, **kwargs):
        return self.plans

    async def list_long_term_memory(self, **kwargs):
        return self.memories

    async def list_entities(self, **kwargs):
        return []

    async def list_entity_events(self, **kwargs):
        return []

    async def list_personal_rules(self, **kwargs):
        return []

    async def list_plan_milestones(self, **kwargs):
        return []


def test_vague_delete_reference_detects_kind_only_targets():
    assert is_vague_delete_reference("commitment")
    assert is_vague_delete_reference("a memory please")
    assert not is_vague_delete_reference("Wake at 5 AM")


def test_parse_delete_request_scopes_saved_commitment_without_title():
    parsed = parse_delete_request("Can you delete the commitment we have saved?")
    assert parsed is not None
    assert parsed.reference == "commitment"
    assert parsed.scope_tables == COMMITMENT_DELETE_SCOPE
    assert parsed.is_vague is True


def test_parse_delete_request_scopes_named_commitment():
    parsed = parse_delete_request('Delete the commitment "Wake at 5 AM"')
    assert parsed is not None
    assert parsed.reference == "Wake at 5 AM"
    assert parsed.scope_tables == COMMITMENT_DELETE_SCOPE
    assert parsed.is_vague is False


@pytest.mark.asyncio
async def test_resolver_returns_empty_for_vague_commitment_delete():
    store = FakeDeleteMemoryStore(
        commitments=[
            {
                "id": "c-1",
                "title": "Wake at 5 AM",
                "commitment_text": "Wake at 5 AM",
                "active": True,
            }
        ],
        memories=[
            {
                "id": "m-1",
                "content": "commitment reminder",
                "active": True,
            }
        ],
    )
    resolver = MemoryDeleteResolver(store)
    parsed = parse_delete_request("Delete the commitment we have saved")
    assert parsed is not None

    matches = await resolver.resolve(parsed)
    assert matches == []


@pytest.mark.asyncio
async def test_resolver_scoped_commitment_delete_skips_memory_tables():
    store = FakeDeleteMemoryStore(
        commitments=[
            {
                "id": "c-1",
                "title": "Wake at 5 AM",
                "commitment_text": "Wake at 5 AM",
                "active": True,
            }
        ],
        memories=[
            {
                "id": "m-1",
                "content": "Wake at 5 AM daily habit",
                "active": True,
            }
        ],
    )
    resolver = MemoryDeleteResolver(store)
    parsed = parse_delete_request('Delete the commitment "Wake at 5 AM"')
    assert parsed is not None

    matches = await resolver.resolve(parsed)
    assert len(matches) == 1
    assert matches[0].table == "commitments"
    assert matches[0].id == "c-1"


@pytest.mark.asyncio
async def test_resolver_unscoped_delete_can_match_memory():
    store = FakeDeleteMemoryStore(
        commitments=[],
        memories=[
            {
                "id": "m-1",
                "content": "Mom birthday is June 18",
                "active": True,
            }
        ],
    )
    resolver = MemoryDeleteResolver(store)
    matches = await resolver.resolve("Mom birthday")
    assert len(matches) == 1
    assert matches[0].table == "long_term_memory"
    assert matches[0].id == "m-1"

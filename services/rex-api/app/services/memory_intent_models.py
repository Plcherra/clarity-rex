from dataclasses import dataclass, field


@dataclass(frozen=True)
class SimpleMemoryIntent:
    memory_type: str
    content: str
    importance: int
    source: str = "simple_memory_intent"
    metadata: dict = field(default_factory=dict)

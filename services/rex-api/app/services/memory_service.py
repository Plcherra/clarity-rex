from typing import Optional

from app.config import Settings, get_settings
from app.services.chat_embedding_service import ChatEmbeddingService
from app.services.conversation_repository import ConversationRepository
from app.services.long_term_memory_repository import LongTermMemoryRepository
from app.services.memory_conversation_gateway import MemoryConversationGateway
from app.services.memory_correction_repository import MemoryCorrectionRepository
from app.services.memory_errors import MemoryServiceError
from app.services.memory_long_term_gateway import MemoryLongTermGateway
from app.services.memory_open_thread_gateway import MemoryOpenThreadGateway
from app.services.memory_retrieval_service import MemoryRetrievalService
from app.services.memory_structured_gateway import MemoryStructuredGateway
from app.services.structured_memory_repository import StructuredMemoryRepository
from app.services.supabase_memory_transport import SupabaseMemoryTransport


class SupabaseMemoryService(
    MemoryConversationGateway,
    MemoryLongTermGateway,
    MemoryOpenThreadGateway,
    MemoryStructuredGateway,
    SupabaseMemoryTransport,
):
    def __init__(
        self,
        settings: Optional[Settings] = None,
        user_id: Optional[str] = None,
        access_token: Optional[str] = None,
        *,
        use_service_role: bool = False,
    ) -> None:
        if use_service_role and access_token:
            raise ValueError(
                "Pass access_token for user-scoped access or "
                "use_service_role=True for ops — not both."
            )
        if not use_service_role and not access_token:
            raise ValueError(
                "SupabaseMemoryService requires access_token or "
                "use_service_role=True (no implicit service-role fallback)."
            )
        self.settings = settings or get_settings()
        self.user_id = user_id
        self.access_token = access_token
        self.use_service_role = use_service_role
        self.chat_embedding_service = ChatEmbeddingService(self.settings)
        self.conversation_repository = ConversationRepository(self)
        self.long_term_memory_repository = LongTermMemoryRepository(self)
        self.memory_retrieval_service = MemoryRetrievalService(self)
        self.structured_memory_repository = StructuredMemoryRepository(self)
        self.memory_correction_repository = MemoryCorrectionRepository(self)


def is_active_memory(memory: dict) -> bool:
    return memory.get("active") is not False


def memory_accountability_text(memory: dict) -> str:
    return " ".join(
        str(memory.get(field) or "")
        for field in ("content", "memory_type", "relevance_reason")
    )

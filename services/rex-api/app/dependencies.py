from fastapi import Depends

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.config import get_settings
from app.services.ai_service import AIService
from app.services.accountability_service import AccountabilityService
from app.services.chat_service import ChatService
from app.services.clarity_control_service import ClarityControlService
from app.services.commitment_service import CommitmentService
from app.services.deepgram_service import DeepgramService
from app.services.deepgram_streaming_service import DeepgramStreamingService
from app.services.entity_service import EntityService
from app.services.file_service import FileService
from app.services.google_tts_service import GoogleTTSService
from app.services.memory_service import SupabaseMemoryService
from app.services.plan_service import PlanService
from app.services.rule_service import RuleService
from app.services.time_context_service import TimeContextService
from app.services.usage_tracking_service import UsageTrackingService


def get_ai_service() -> AIService:
    return AIService()


def get_memory_service(
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> SupabaseMemoryService:
    return SupabaseMemoryService(
        user_id=current_user.id,
        access_token=current_user.access_token,
    )


def get_clarity_control_service(
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> ClarityControlService:
    return ClarityControlService(
        user_id=current_user.id,
        access_token=current_user.access_token,
    )


def get_entity_service(
    memory_service: SupabaseMemoryService = Depends(get_memory_service),
) -> EntityService:
    return EntityService(memory_service)


def get_rule_service(
    memory_service: SupabaseMemoryService = Depends(get_memory_service),
) -> RuleService:
    return RuleService(memory_service)


def get_plan_service(
    memory_service: SupabaseMemoryService = Depends(get_memory_service),
) -> PlanService:
    return PlanService(memory_service)


def get_commitment_service(
    memory_service: SupabaseMemoryService = Depends(get_memory_service),
) -> CommitmentService:
    return CommitmentService(memory_service)


def get_accountability_service() -> AccountabilityService:
    return AccountabilityService()


def get_deepgram_service() -> DeepgramService:
    return DeepgramService()


def get_deepgram_streaming_service() -> DeepgramStreamingService:
    return DeepgramStreamingService()


def get_google_tts_service() -> GoogleTTSService:
    return GoogleTTSService()


def get_usage_tracking_service() -> UsageTrackingService:
    return UsageTrackingService()


def get_chat_service(
    ai_service: AIService = Depends(get_ai_service),
    memory_service: SupabaseMemoryService = Depends(get_memory_service),
    usage_tracking_service: UsageTrackingService = Depends(get_usage_tracking_service),
) -> ChatService:
    settings = get_settings()
    return ChatService(
        ai_service,
        FileService(),
        memory_service,
        time_context_service=TimeContextService(timezone_name=settings.app_timezone),
        accountability_service=get_accountability_service(),
        usage_tracking_service=usage_tracking_service,
    )

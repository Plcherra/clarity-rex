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
from app.services.plaid_account_service import PlaidAccountService
from app.services.plaid_api_client import PlaidApiClient
from app.services.plaid_cursor_service import PlaidCursorService
from app.services.plaid_sync_service import PlaidSyncService
from app.services.plaid_token_service import PlaidTokenService
from app.services.plaid_transaction_service import PlaidTransactionService
from app.services.plaid_webhook_service import PlaidWebhookService
from app.services.plaid_webhook_verifier import PlaidWebhookVerifier
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


def get_plaid_api_client() -> PlaidApiClient:
    return PlaidApiClient()


def get_plaid_token_service() -> PlaidTokenService:
    return PlaidTokenService()


def get_plaid_cursor_service() -> PlaidCursorService:
    return PlaidCursorService()


def get_plaid_account_service(
    plaid_api_client: PlaidApiClient = Depends(get_plaid_api_client),
    plaid_cursor_service: PlaidCursorService = Depends(get_plaid_cursor_service),
) -> PlaidAccountService:
    return PlaidAccountService(
        plaid_client=plaid_api_client,
        cursor_service=plaid_cursor_service,
    )


def get_plaid_transaction_service(
    plaid_api_client: PlaidApiClient = Depends(get_plaid_api_client),
    plaid_cursor_service: PlaidCursorService = Depends(get_plaid_cursor_service),
) -> PlaidTransactionService:
    return PlaidTransactionService(
        plaid_client=plaid_api_client,
        cursor_service=plaid_cursor_service,
    )


def get_plaid_sync_service(
    plaid_api_client: PlaidApiClient = Depends(get_plaid_api_client),
    plaid_token_service: PlaidTokenService = Depends(get_plaid_token_service),
    plaid_cursor_service: PlaidCursorService = Depends(get_plaid_cursor_service),
    plaid_account_service: PlaidAccountService = Depends(get_plaid_account_service),
    plaid_transaction_service: PlaidTransactionService = Depends(
        get_plaid_transaction_service,
    ),
) -> PlaidSyncService:
    return PlaidSyncService(
        plaid_client=plaid_api_client,
        token_service=plaid_token_service,
        cursor_service=plaid_cursor_service,
        account_service=plaid_account_service,
        transaction_service=plaid_transaction_service,
    )


def get_plaid_webhook_verifier(
    plaid_api_client: PlaidApiClient = Depends(get_plaid_api_client),
) -> PlaidWebhookVerifier:
    return PlaidWebhookVerifier(plaid_client=plaid_api_client)


def get_plaid_webhook_service(
    plaid_sync_service: PlaidSyncService = Depends(get_plaid_sync_service),
    plaid_webhook_verifier: PlaidWebhookVerifier = Depends(get_plaid_webhook_verifier),
) -> PlaidWebhookService:
    return PlaidWebhookService(plaid_sync_service, plaid_webhook_verifier)


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

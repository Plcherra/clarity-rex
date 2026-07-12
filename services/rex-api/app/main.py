from contextlib import asynccontextmanager
import logging

from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.config import get_settings
from app.logging_filters import install_sensitive_query_log_filters
from app.routes.accountability import router as accountability_router
from app.routes.apple_app_site_association import (
    router as apple_app_site_association_router,
)
from app.routes.insights import router as insights_router
from app.routes.chat import router as chat_router
from app.routes.clarity import router as clarity_router
from app.routes.open_threads import router as open_threads_router
from app.routes.conversations import router as conversations_router
from app.routes.entities import router as entities_router
from app.routes.finance_audit import router as finance_audit_router
from app.routes.memory import router as memory_router
from app.routes.plaid import router as plaid_router
from app.routes.plaid_webhooks import router as plaid_webhook_router
from app.routes.plans import router as plans_router
from app.routes.rules import router as rules_router
from app.routes.saved_knowledge import router as saved_knowledge_router
from app.routes.usage import router as usage_router
from app.routes.voice import router as voice_router
from app.routes.voice_stream import router as voice_stream_router
from app.services.http_client import shutdown_http_client, startup_http_client
from app.services.plaid_config import get_plaid_config_status
from app.services.product_events import emit_api_5xx
from app.services.sentry_setup import capture_exception, init_sentry

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    startup_errors = settings.startup_validation_errors()
    if startup_errors:
        message = "Startup configuration invalid: " + ", ".join(startup_errors)
        logger.error(message)
        raise RuntimeError(message)

    install_sensitive_query_log_filters()
    await startup_http_client()
    logger.info(
        "Google TTS configured: voice=%s rate=%s pitch=%s",
        settings.google_tts_voice_name,
        settings.google_tts_speaking_rate,
        settings.google_tts_pitch,
    )
    try:
        yield
    finally:
        await shutdown_http_client()


settings = get_settings()
init_sentry(settings)
install_sensitive_query_log_filters()

app = FastAPI(title="Clarity API", lifespan=lifespan)

if settings.cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


@app.middleware("http")
async def observability_http_middleware(request: Request, call_next):
    try:
        response = await call_next(request)
    except Exception as error:
        emit_api_5xx(
            status_code=500,
            method=request.method,
            path=request.url.path,
        )
        capture_exception(error)
        logger.exception(
            "unhandled_request_error method=%s path=%s error_class=%s",
            request.method,
            request.url.path,
            type(error).__name__,
        )
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error."},
        )

    if response.status_code >= 500:
        emit_api_5xx(
            status_code=response.status_code,
            method=request.method,
            path=request.url.path,
        )
    return response


@app.get("/")
def health_check() -> dict[str, str]:
    return {"status": "ok", "service": "clarity-rex"}


@app.get("/ready")
def readiness_check() -> dict[str, str]:
    """Public readiness — status only. Details require auth via /ready/details."""
    return {"status": "ok", "service": "clarity-rex"}


@app.get("/ready/details")
def readiness_details(
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> dict:
    _ = current_user
    plaid_status = get_plaid_config_status(settings)
    plaid_required = settings.is_production
    checks = {
        "grok": {
            "configured": bool(settings.grok_api_key and settings.grok_model),
            "required": ["GROK_API_KEY", "GROK_MODEL"],
            "model": settings.grok_model,
        },
        "assistant_pipeline": {
            "configured": True,
            "mode": "simple",
            "description": (
                "Production assistant pipeline (SimpleRexBrain) for chat and voice."
            ),
            "models": {
                "fallback": settings.grok_model,
                "fast": settings.grok_fast_model or settings.grok_model,
                "standard": settings.grok_standard_model or settings.grok_model,
                "reasoning": settings.grok_reasoning_model or settings.grok_model,
            },
        },
        "supabase": {
            "configured": bool(
                settings.supabase_url
                and settings.supabase_anon_key
                and (
                    not settings.is_production
                    or settings.supabase_service_role_key
                )
            ),
            "required": [
                "SUPABASE_URL",
                "SUPABASE_ANON_KEY",
                *(
                    ["SUPABASE_SERVICE_ROLE_KEY"]
                    if settings.is_production
                    else []
                ),
            ],
            "optional": (
                []
                if settings.is_production
                else ["SUPABASE_SERVICE_ROLE_KEY"]
            ),
        },
        "deepgram": {
            "configured": bool(settings.deepgram_api_key),
            "required": ["DEEPGRAM_API_KEY"],
            "model": settings.deepgram_model,
            "language": settings.deepgram_language,
        },
        "google_tts": {
            "configured": settings.google_tts_is_configured,
            "required": [
                "GOOGLE_TTS_PROJECT_ID",
                "GOOGLE_TTS_CREDENTIALS_JSON or GOOGLE_APPLICATION_CREDENTIALS",
            ],
            "voice_name": settings.google_tts_voice_name,
            "language_code": settings.google_tts_language_code,
            "audio_encoding": settings.google_tts_audio_encoding,
            "speaking_rate": settings.google_tts_speaking_rate,
            "pitch": settings.google_tts_pitch,
            "volume_gain_db": settings.google_tts_volume_gain_db,
        },
        "plaid": plaid_status.to_readiness(required_for_ready=plaid_required),
        "sentry": {
            "configured": bool((settings.sentry_dsn or "").strip()),
            "required_for_ready": False,
            "required": [],
        },
        "time": {
            "configured": bool(settings.app_timezone),
            "timezone": settings.app_timezone,
        },
    }
    required_checks = [
        check
        for check in checks.values()
        if check.get("required_for_ready", True)
    ]
    return {
        "status": (
            "ready"
            if all(check["configured"] for check in required_checks)
            else "degraded"
        ),
        "service": "clarity-rex",
        "systemd_unit": "clarity-rex.service",
        "checks": checks,
    }


auth_dependencies = [Depends(get_current_user)]

app.include_router(chat_router, dependencies=auth_dependencies)
app.include_router(insights_router, dependencies=auth_dependencies)
app.include_router(clarity_router, dependencies=auth_dependencies)
app.include_router(finance_audit_router, dependencies=auth_dependencies)
app.include_router(conversations_router, dependencies=auth_dependencies)
app.include_router(memory_router, dependencies=auth_dependencies)
app.include_router(entities_router, dependencies=auth_dependencies)
app.include_router(rules_router, dependencies=auth_dependencies)
app.include_router(plans_router, dependencies=auth_dependencies)
app.include_router(open_threads_router, dependencies=auth_dependencies)
app.include_router(saved_knowledge_router, dependencies=auth_dependencies)
app.include_router(accountability_router, dependencies=auth_dependencies)
app.include_router(usage_router, dependencies=auth_dependencies)
app.include_router(apple_app_site_association_router)
app.include_router(plaid_router)
app.include_router(plaid_webhook_router)
app.include_router(voice_router, dependencies=auth_dependencies)
app.include_router(voice_stream_router)

from contextlib import asynccontextmanager
import logging

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.auth.supabase_auth import get_current_user
from app.config import get_settings
from app.routes.accountability import router as accountability_router
from app.routes.apple_app_site_association import (
    router as apple_app_site_association_router,
)
from app.routes.chat import router as chat_router
from app.routes.clarity import router as clarity_router
from app.routes.commitments import router as commitments_router
from app.routes.conversations import router as conversations_router
from app.routes.entities import router as entities_router
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

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    production_errors = settings.production_validation_errors()
    if production_errors:
        message = (
            "Production configuration incomplete: "
            + ", ".join(production_errors)
        )
        logger.error(message)
        raise RuntimeError(message)

    await startup_http_client()
    try:
        yield
    finally:
        await shutdown_http_client()


app = FastAPI(title="Clarity API", lifespan=lifespan)
settings = get_settings()

if settings.cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


@app.get("/")
def health_check() -> dict[str, str]:
    return {"status": "ok", "service": "clarity-rex"}


@app.get("/ready")
def readiness_check() -> dict:
    plaid_status = get_plaid_config_status(settings)
    checks = {
        "grok": {
            "configured": bool(settings.grok_api_key and settings.grok_model),
            "required": ["GROK_API_KEY", "GROK_MODEL"],
            "model": settings.grok_model,
        },
        "rex_brain": {
            "configured": True,
            "mode": "simple",
            "description": (
                "Simple Rex Brain is the production launch brain for chat and voice."
            ),
            "models": {
                "fallback": settings.grok_model,
                "fast": settings.grok_fast_model or settings.grok_model,
                "standard": settings.grok_standard_model or settings.grok_model,
                "reasoning": settings.grok_reasoning_model or settings.grok_model,
            },
        },
        "supabase": {
            "configured": bool(settings.supabase_url and settings.supabase_anon_key),
            "required": [
                "SUPABASE_URL",
                "SUPABASE_ANON_KEY",
            ],
            "optional": ["SUPABASE_SERVICE_ROLE_KEY"],
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
        },
        "plaid": plaid_status.to_readiness(),
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
app.include_router(clarity_router, dependencies=auth_dependencies)
app.include_router(conversations_router, dependencies=auth_dependencies)
app.include_router(memory_router, dependencies=auth_dependencies)
app.include_router(entities_router, dependencies=auth_dependencies)
app.include_router(rules_router, dependencies=auth_dependencies)
app.include_router(plans_router, dependencies=auth_dependencies)
app.include_router(commitments_router, dependencies=auth_dependencies)
app.include_router(saved_knowledge_router, dependencies=auth_dependencies)
app.include_router(accountability_router, dependencies=auth_dependencies)
app.include_router(usage_router, dependencies=auth_dependencies)
app.include_router(apple_app_site_association_router)
app.include_router(plaid_router)
app.include_router(plaid_webhook_router)
app.include_router(voice_router, dependencies=auth_dependencies)
app.include_router(voice_stream_router)

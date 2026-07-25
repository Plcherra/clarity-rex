from functools import lru_cache
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict

# Only these values are accepted. Typos like "prod" must not silently
# enable development auth bypass or skip production validation.
KNOWN_APP_ENVIRONMENTS = frozenset({"development", "production"})


class Settings(BaseSettings):
    app_environment: str = "development"
    app_timezone: str = "America/New_York"
    cors_allowed_origins: str = ""
    sentry_dsn: Optional[str] = None
    sentry_traces_sample_rate: float = 0.1

    grok_api_key: Optional[str] = None
    grok_base_url: str = "https://api.x.ai/v1"
    grok_model: Optional[str] = None
    grok_fast_model: Optional[str] = None
    grok_standard_model: Optional[str] = None
    grok_reasoning_model: Optional[str] = None
    grok_embedding_model: Optional[str] = None
    grok_embedding_dimensions: int = 1536
    grok_timeout_seconds: int = 120
    rex_log_grok_prompt: bool = False

    # Auto save/track proposals (dev/ops override only): off | text | card
    # Leave unset in production. Profile Off always wins over env Card/Text.
    rex_auto_proposals_mode: Optional[str] = None
    rex_auto_proposals_threads: Optional[bool] = None
    rex_auto_proposals_goals: Optional[bool] = None
    rex_auto_proposals_memory: Optional[bool] = None

    supabase_url: Optional[str] = None
    supabase_anon_key: Optional[str] = None
    supabase_service_role_key: Optional[str] = None
    supabase_conversations_table: str = "conversations"
    supabase_messages_table: str = "messages"
    supabase_chat_search_embeddings_table: str = "chat_search_embeddings"
    supabase_long_term_memory_table: str = "long_term_memory"
    supabase_memory_corrections_table: str = "memory_corrections"
    supabase_voice_turns_table: str = "voice_turns"
    usage_owner_user_id: Optional[str] = None
    usage_grok_cents_per_1k_tokens: float = 0.0
    usage_grok_input_cents_per_1k_tokens: float = 0.125
    usage_grok_output_cents_per_1k_tokens: float = 0.25
    usage_deepgram_cents_per_minute: float = 0.0
    usage_tts_cents_per_minute: float = 0.0
    usage_tts_cents_per_1k_chars: float = 1.6

    plaid_client_id: Optional[str] = None
    plaid_secret: Optional[str] = None
    plaid_environment: str = "sandbox"
    plaid_products: str = "transactions"
    plaid_country_codes: str = "US"
    plaid_redirect_uri: Optional[str] = None
    plaid_web_redirect_uri: Optional[str] = None
    plaid_webhook_url: Optional[str] = None
    plaid_ios_bundle_id: Optional[str] = "app.goclarity.clarity"
    plaid_android_package_name: Optional[str] = "com.clarity.clarity"
    plaid_account_filters_json: Optional[str] = None
    plaid_timeout_seconds: int = 30
    plaid_token_encryption_secret: Optional[str] = None
    plaid_enable_transactions_refresh: bool = False

    deepgram_api_key: Optional[str] = None
    deepgram_model: str = "nova-3"
    deepgram_language: str = "en-US"
    deepgram_base_url: str = "https://api.deepgram.com/v1"
    deepgram_timeout_seconds: int = 60
    # Conversational endpointing: tolerate breath/think pauses (~1.5s) without
    # leaving listening stuck. Finish still lands ~1.6–1.8s after last speech.
    deepgram_endpointing_ms: int = 1600
    deepgram_live_transcript_idle_ms: int = 1800
    # Spanish TTS: Aura-2 Gloria (Colombian). English still uses Google TTS.
    deepgram_tts_spanish_enabled: bool = True
    deepgram_tts_model_es: str = "aura-2-gloria-es"
    deepgram_tts_encoding: str = "mp3"

    google_tts_project_id: Optional[str] = None
    google_tts_credentials_json: Optional[str] = None
    google_application_credentials: Optional[str] = None
    google_tts_base_url: str = "https://texttospeech.googleapis.com/v1"
    google_tts_voice_name: str = "en-US-Neural2-J"
    google_tts_language_code: str = "en-US"
    google_tts_audio_encoding: str = "MP3"
    google_tts_speaking_rate: float = 1.15
    google_tts_pitch: float = 0.0
    google_tts_volume_gain_db: float = 10.0
    google_tts_timeout_seconds: int = 60

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def grok_chat_url(self) -> str:
        return f"{self.grok_base_url.rstrip('/')}/chat/completions"

    @property
    def grok_embeddings_url(self) -> str:
        return f"{self.grok_base_url.rstrip('/')}/embeddings"

    @property
    def supabase_rest_url(self) -> Optional[str]:
        if not self.supabase_url:
            return None

        return f"{self.supabase_url.rstrip('/')}/rest/v1"

    @property
    def deepgram_transcription_url(self) -> str:
        return f"{self.deepgram_base_url.rstrip('/')}/listen"

    @property
    def deepgram_speak_url(self) -> str:
        return f"{self.deepgram_base_url.rstrip('/')}/speak"

    @property
    def google_tts_is_configured(self) -> bool:
        return bool(
            self.google_tts_project_id
            and (
                self.google_tts_credentials_json or self.google_application_credentials
            )
        )

    @property
    def google_tts_synthesize_url(self) -> str:
        return f"{self.google_tts_base_url.rstrip('/')}/text:synthesize"

    @property
    def plaid_base_url(self) -> str:
        environment = self.plaid_environment.strip().lower()
        if environment == "production":
            return "https://production.plaid.com"
        if environment == "development":
            return "https://development.plaid.com"
        return "https://sandbox.plaid.com"

    @property
    def cloud_voice_is_configured(self) -> bool:
        return bool(self.deepgram_api_key and self.google_tts_is_configured)

    @property
    def cors_origins(self) -> list[str]:
        return [
            origin.strip()
            for origin in self.cors_allowed_origins.split(",")
            if origin.strip()
        ]

    @property
    def normalized_app_environment(self) -> str:
        return self.app_environment.strip().lower()

    @property
    def is_production(self) -> bool:
        return self.normalized_app_environment == "production"

    @property
    def allows_unauthenticated_dev_user(self) -> bool:
        """Fake auth user only in local development — never for typos or prod."""
        return self.normalized_app_environment == "development"

    def environment_validation_errors(self) -> list[str]:
        if self.normalized_app_environment in KNOWN_APP_ENVIRONMENTS:
            return []
        allowed = ", ".join(sorted(KNOWN_APP_ENVIRONMENTS))
        return [
            f"APP_ENVIRONMENT must be one of: {allowed} "
            f"(got {self.app_environment!r})"
        ]

    def production_validation_errors(self) -> list[str]:
        if not self.is_production:
            return []

        errors: list[str] = []
        if not self.grok_api_key:
            errors.append("GROK_API_KEY")
        if not self.grok_model:
            errors.append("GROK_MODEL")
        if not self.supabase_url:
            errors.append("SUPABASE_URL")
        if not self.supabase_anon_key:
            errors.append("SUPABASE_ANON_KEY")
        if not self.deepgram_api_key:
            errors.append("DEEPGRAM_API_KEY")
        if not self.google_tts_is_configured:
            errors.append(
                "GOOGLE_TTS_PROJECT_ID with GOOGLE_TTS_CREDENTIALS_JSON "
                "or GOOGLE_APPLICATION_CREDENTIALS"
            )
        # Usage tracking + Plaid persistence need service role at runtime.
        if not self.supabase_service_role_key:
            errors.append("SUPABASE_SERVICE_ROLE_KEY")
        if self._plaid_credentials_present():
            if not (self.plaid_token_encryption_secret or "").strip():
                errors.append("PLAID_TOKEN_ENCRYPTION_SECRET")
            from app.services.plaid_config import get_plaid_config_status

            plaid_status = get_plaid_config_status(self)
            if not plaid_status.configured:
                errors.extend(plaid_status.missing)
                errors.extend(plaid_status.invalid)
        return errors

    def _plaid_credentials_present(self) -> bool:
        return bool(
            (self.plaid_client_id or "").strip()
            or (self.plaid_secret or "").strip()
        )

    def startup_validation_errors(self) -> list[str]:
        return [
            *self.environment_validation_errors(),
            *self.production_validation_errors(),
        ]


@lru_cache
def get_settings() -> Settings:
    return Settings()

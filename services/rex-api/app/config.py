from functools import lru_cache
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_environment: str = "development"
    app_timezone: str = "America/New_York"
    cors_allowed_origins: str = ""

    grok_api_key: Optional[str] = None
    grok_base_url: str = "https://api.x.ai/v1"
    grok_model: Optional[str] = None
    grok_fast_model: Optional[str] = None
    grok_standard_model: Optional[str] = None
    grok_reasoning_model: Optional[str] = None
    grok_embedding_model: Optional[str] = None
    grok_embedding_dimensions: int = 1536
    grok_timeout_seconds: int = 120

    # Brain prompt experiment: production | raw | raw_truth
    rex_brain_prompt_mode: str = "production"
    rex_voice_instructions_enabled: bool = True
    rex_log_grok_prompt: bool = False

    # Auto save/track proposals (dev override only): off | text | card
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
    deepgram_endpointing_ms: int = 900
    deepgram_live_transcript_idle_ms: int = 1100

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
    def is_production(self) -> bool:
        return self.app_environment.strip().lower() == "production"

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
        return errors


@lru_cache
def get_settings() -> Settings:
    return Settings()

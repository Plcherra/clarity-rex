from typing import Optional


class ChatVoiceMetadataMixin:
    async def save_voice_turn_metadata(
        self,
        conversation_id: str,
        user_message_id: Optional[str] = None,
        assistant_message_id: Optional[str] = None,
        transcript_confidence: Optional[float] = None,
        audio_duration_seconds: Optional[float] = None,
        input_mime_type: Optional[str] = None,
        output_audio_encoding: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> Optional[dict]:
        try:
            return await self.memory_service.save_voice_turn(
                conversation_id=conversation_id,
                user_message_id=user_message_id,
                assistant_message_id=assistant_message_id,
                transcript_confidence=transcript_confidence,
                audio_duration_seconds=audio_duration_seconds,
                input_mime_type=input_mime_type,
                output_audio_encoding=output_audio_encoding,
                metadata=metadata,
            )
        except Exception:
            # Voice metadata is useful, but raw conversation success should not
            # depend on trace metadata persistence.
            return None

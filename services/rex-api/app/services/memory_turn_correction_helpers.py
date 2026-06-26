from app.services.memory_correction_types import CorrectionIntentType


class MemoryTurnCorrectionHelpers:
    async def _try_apply_direct_correction(
        self,
        message: str,
        *,
        conversation_id: str,
        user_message: dict,
    ) -> dict | None:
        intent = self.memory_correction_service.detect_correction_intent(message)
        if intent.intent_type != CorrectionIntentType.REPLACE_VALUE:
            return None
        if not intent.old_value or not intent.new_value:
            return None

        report = await self.memory_correction_service.apply_correction(
            message,
            source_conversation_id=conversation_id,
            source_message_id=str(user_message.get("id") or "") or None,
        )

        if report.requires_confirmation:
            response = (
                f"Got it — I found multiple saved items that mention "
                f"{intent.old_value}. Tell me the exact saved item to update."
            )
            return await self._correction_turn_result(
                response,
                conversation_id=conversation_id,
                user_message=user_message,
                memory_changes=self._correction_ambiguous_summary(intent, report),
            )

        if not report.applied or not report.affected_records:
            return None

        response = (
            f"Got it — I updated saved memory from {intent.old_value} to "
            f"{intent.new_value}."
        )
        return await self._correction_turn_result(
            response,
            conversation_id=conversation_id,
            user_message=user_message,
            memory_changes=self._correction_applied_summary(report),
            memory_correction=report.as_dict(),
        )

    async def _correction_turn_result(
        self,
        response: str,
        *,
        conversation_id: str,
        user_message: dict,
        memory_changes: dict,
        memory_correction: dict | None = None,
    ) -> dict:
        assistant_message = await self.memory_service.save_message(
            conversation_id,
            "assistant",
            response,
        )
        return {
            "conversation_id": conversation_id,
            "response": response,
            "user_message": user_message,
            "assistant_message": self.public_message(assistant_message),
            "memory_correction": memory_correction,
            "memory_changes": memory_changes,
            "messages": await self.recent_public_messages(conversation_id),
        }

    def _correction_applied_summary(self, report) -> dict:
        return {
            "created": 0,
            "updated": len(report.affected_records),
            "archived": 0,
            "merged": 0,
            "skipped": 0,
            "confirmation_required": 0,
            "records": [
                {
                    "kind": record.table,
                    "type": report.intent.intent_type.value,
                    "action": record.action,
                    "id": record.id,
                    "title": record.title,
                }
                for record in report.affected_records
            ],
        }

    def _correction_ambiguous_summary(self, intent, report) -> dict:
        return {
            "created": 0,
            "updated": 0,
            "archived": 0,
            "merged": 0,
            "skipped": 1,
            "confirmation_required": 1,
            "records": [
                {
                    "kind": "memory_correction",
                    "type": intent.intent_type.value,
                    "action": "confirmation_required",
                    "title": intent.old_value,
                    "metadata": report.confirmation_payload or {},
                }
            ],
        }

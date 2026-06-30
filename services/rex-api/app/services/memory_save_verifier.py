from typing import Optional


class MemorySaveVerifier:
    async def _confirmed_visible_active_memory(self, record: dict) -> Optional[dict]:
        record_id = str(record.get("id") or "")
        if not record_id:
            return None

        list_memory = getattr(self.memory_service, "list_long_term_memory", None)
        if list_memory is None:
            return None

        try:
            memories = await list_memory(
                limit=100,
                memory_type=record.get("memory_type"),
                active=True,
            )
        except TypeError:
            try:
                memories = await list_memory(limit=100, active=True)
            except Exception:
                return None
        except Exception:
            return None

        for memory in memories:
            if str(memory.get("id") or "") == record_id:
                return memory
        return None

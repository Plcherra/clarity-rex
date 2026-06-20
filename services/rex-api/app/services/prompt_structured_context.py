from typing import Optional

from app.services.prompt_constants import (
    MAX_STRUCTURED_MEMORY_CONTEXT_CHARACTERS,
    STRUCTURED_MEMORY_PREFIX,
)


class PromptStructuredContextMixin:
    def _structured_memory_section(
        self,
        structured_context: dict,
        *,
        saved_memory_count: int = 0,
    ) -> Optional[str]:
        if not structured_context:
            return None

        lines: list[str] = []
        used_characters = 0
        entity_names = self._entity_name_map(structured_context.get("entities") or [])
        plan_titles = self._plan_title_map(structured_context.get("plans") or [])

        used_characters = self._append_structured_line(
            lines,
            used_characters,
            self._recall_status_line(
                structured_context.get("memory_status"),
                saved_memory_count=saved_memory_count,
            ),
        )
        for entity in structured_context.get("entities") or []:
            used_characters = self._append_structured_line(
                lines,
                used_characters,
                self._entity_line(entity),
            )
        for event in structured_context.get("entity_events") or []:
            used_characters = self._append_structured_line(
                lines,
                used_characters,
                self._entity_event_line(event, entity_names),
            )
        for rule in structured_context.get("personal_rules") or []:
            used_characters = self._append_structured_line(
                lines,
                used_characters,
                self._personal_rule_line(rule),
            )
        for plan in structured_context.get("plans") or []:
            used_characters = self._append_structured_line(
                lines,
                used_characters,
                self._plan_line(plan, entity_names),
            )
        for milestone in structured_context.get("plan_milestones") or []:
            used_characters = self._append_structured_line(
                lines,
                used_characters,
                self._milestone_line(milestone, plan_titles),
            )
        for commitment in structured_context.get("commitments") or []:
            used_characters = self._append_structured_line(
                lines,
                used_characters,
                self._commitment_line(commitment, entity_names, plan_titles),
            )

        if not lines:
            return None
        return f"{STRUCTURED_MEMORY_PREFIX}{chr(10).join(lines)}"

    def _append_structured_line(
        self,
        lines: list[str],
        used_characters: int,
        line: Optional[str],
    ) -> int:
        if not line:
            return used_characters

        remaining_characters = (
            MAX_STRUCTURED_MEMORY_CONTEXT_CHARACTERS - used_characters
        )
        if remaining_characters <= 0:
            return used_characters
        if len(line) > remaining_characters:
            if remaining_characters < 40:
                return used_characters
            line = f"{line[: remaining_characters - 22].rstrip()} [truncated]"

        lines.append(line)
        return used_characters + len(line) + 1

    def _recall_status_line(
        self,
        status: object,
        *,
        saved_memory_count: int,
    ) -> Optional[str]:
        if not isinstance(status, dict):
            return None
        failure_sources: list[str] = []
        failures = status.get("failures")
        if isinstance(failures, list):
            for failure in failures:
                if not isinstance(failure, dict):
                    continue
                source = failure.get("source")
                if source:
                    failure_sources.append(str(source))

        attempted_sources = status.get("attempted_sources")
        saved_attempted = False
        if isinstance(attempted_sources, dict):
            saved_attempted = any(
                attempted_sources.get(source)
                for source in (
                    "long_term_memory",
                    "profile_memory",
                    "structured_memory",
                )
            )
        saved_failures = [
            source for source in failure_sources if source != "chat_search"
        ]
        if saved_failures:
            saved_state = "degraded"
        elif saved_memory_count > 0:
            saved_state = "found"
        elif saved_attempted:
            saved_state = "empty"
        else:
            saved_state = "not_requested"

        chat_state = "not_requested"
        chat_count = 0
        source_statuses = status.get("source_statuses")
        if isinstance(source_statuses, list):
            for source_status in source_statuses:
                if not isinstance(source_status, dict):
                    continue
                if source_status.get("source") != "chat_search":
                    continue
                if source_status.get("attempted") is not True:
                    break
                chat_count = int(source_status.get("result_count") or 0)
                if (
                    source_status.get("succeeded") is not True
                    or source_status.get("partial") is True
                    or "chat_search" in failure_sources
                ):
                    chat_state = "degraded"
                elif chat_count > 0:
                    chat_state = "found"
                else:
                    chat_state = "empty"
                break
        elif "chat_search" in failure_sources:
            chat_state = "degraded"

        if saved_state == "not_requested" and chat_state == "not_requested":
            return None

        line = (
            "- recall_status: "
            f"saved_memory={saved_state} count={saved_memory_count}; "
            f"chat_search={chat_state} count={chat_count}."
        )
        if chat_state == "found":
            line = f"{line} Use chat results as chat history, not saved memory."
        if saved_state == "degraded" or chat_state == "degraded":
            failed = ", ".join(sorted(set(failure_sources))) or "unknown"
            line = (
                f"{line} Failed sources: {failed}. Say search is temporarily "
                "unavailable instead of claiming nothing was found."
            )
        elif chat_state == "empty":
            line = (
                f"{line} If answering no, say you searched saved memory and "
                "old chats but could not find anything about that."
            )
        return line

    def _entity_line(self, entity: dict) -> Optional[str]:
        name = entity.get("display_name") or entity.get("normalized_name")
        if not name:
            return None

        parts = [f"- entity/{entity.get('entity_type') or 'unknown'} {name}"]
        relationship = entity.get("relationship")
        if relationship:
            parts.append(str(relationship))
        summary = entity.get("summary")
        if summary:
            parts.append(str(summary))
        return self._with_relevance(" - ".join(parts), entity)

    def _entity_event_line(
        self,
        event: dict,
        entity_names: dict[str, str],
    ) -> Optional[str]:
        title = event.get("title")
        content = event.get("content")
        if not title and not content:
            return None

        entity_name = entity_names.get(str(event.get("entity_id") or ""))
        subject = f" for {entity_name}" if entity_name else ""
        line = f"- entity_event/{event.get('event_type') or 'event'}{subject}"
        if title:
            line = f"{line}: {title}"
        if content:
            line = f"{line} - {content}"
        occurred_at = event.get("occurred_at")
        if occurred_at:
            line = f"{line} (occurred: {occurred_at})"
        return line

    def _personal_rule_line(self, rule: dict) -> Optional[str]:
        title = rule.get("title")
        rule_text = rule.get("rule_text")
        if not title and not rule_text:
            return None

        line = f"- rule/{rule.get('rule_type') or 'personal'}"
        if title:
            line = f"{line} {title}"
        if rule_text:
            line = f"{line}: {rule_text}"
        return self._with_relevance(line, rule)

    def _plan_line(self, plan: dict, entity_names: dict[str, str]) -> Optional[str]:
        title = plan.get("title")
        if not title:
            return None

        line = f"- plan/{plan.get('plan_type') or 'goal'} {title}"
        entity_name = entity_names.get(str(plan.get("primary_entity_id") or ""))
        if entity_name:
            line = f"{line} for {entity_name}"
        desired_outcome = plan.get("desired_outcome")
        description = plan.get("description")
        if desired_outcome:
            line = f"{line}: {desired_outcome}"
        elif description:
            line = f"{line}: {description}"
        target_date = plan.get("target_date")
        if target_date:
            line = f"{line} (target: {target_date})"
        return self._with_relevance(line, plan)

    def _milestone_line(
        self,
        milestone: dict,
        plan_titles: dict[str, str],
    ) -> Optional[str]:
        title = milestone.get("title")
        if not title:
            return None

        plan_title = plan_titles.get(str(milestone.get("plan_id") or ""))
        subject = f" for {plan_title}" if plan_title else ""
        line = (
            f"- milestone/{milestone.get('milestone_type') or 'step'}{subject}: {title}"
        )
        description = milestone.get("description")
        if description:
            line = f"{line} - {description}"
        target_date = milestone.get("target_date")
        if target_date:
            line = f"{line} (target: {target_date})"
        return line

    def _commitment_line(
        self,
        commitment: dict,
        entity_names: dict[str, str],
        plan_titles: dict[str, str],
    ) -> Optional[str]:
        title = commitment.get("title")
        text = commitment.get("commitment_text")
        if not title and not text:
            return None

        line = f"- commitment/{commitment.get('commitment_type') or 'deadline'}"
        if title:
            line = f"{line} {title}"
        if text:
            line = f"{line}: {text}"

        links = []
        entity_name = entity_names.get(str(commitment.get("entity_id") or ""))
        if entity_name:
            links.append(f"person: {entity_name}")
        plan_title = plan_titles.get(str(commitment.get("plan_id") or ""))
        if plan_title:
            links.append(f"plan: {plan_title}")
        due_at = commitment.get("due_at")
        if due_at:
            links.append(f"due: {due_at}")
        if links:
            line = f"{line} ({'; '.join(links)})"
        return self._with_relevance(line, commitment)

    def _with_relevance(self, line: str, record: dict) -> str:
        relevance_reason = record.get("relevance_reason")
        if relevance_reason:
            return f"{line} (why recalled: {relevance_reason})"
        return line

    def _entity_name_map(self, entities: list[dict]) -> dict[str, str]:
        return {
            str(entity["id"]): str(
                entity.get("display_name") or entity.get("normalized_name")
            )
            for entity in entities
            if entity.get("id")
            and (entity.get("display_name") or entity.get("normalized_name"))
        }

    def _plan_title_map(self, plans: list[dict]) -> dict[str, str]:
        return {
            str(plan["id"]): str(plan["title"])
            for plan in plans
            if plan.get("id") and plan.get("title")
        }

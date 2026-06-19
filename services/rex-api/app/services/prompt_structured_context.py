from typing import Optional

from app.services.prompt_constants import (
    MAX_STRUCTURED_MEMORY_CONTEXT_CHARACTERS,
    STRUCTURED_MEMORY_PREFIX,
)


class PromptStructuredContextMixin:
    def _structured_memory_section(self, structured_context: dict) -> Optional[str]:
        if not structured_context:
            return None

        lines: list[str] = []
        used_characters = 0
        entity_names = self._entity_name_map(structured_context.get("entities") or [])
        plan_titles = self._plan_title_map(structured_context.get("plans") or [])

        used_characters = self._append_structured_line(
            lines,
            used_characters,
            self._memory_status_line(structured_context.get("memory_status")),
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

    def _memory_status_line(self, status: object) -> Optional[str]:
        if not isinstance(status, dict):
            return None
        state = str(status.get("state") or "ready")

        message = str(
            status.get("message") or "Some memory sources could not be searched."
        )
        failure_sources = []
        failures = status.get("failures")
        if isinstance(failures, list):
            for failure in failures:
                if not isinstance(failure, dict):
                    continue
                source = failure.get("source")
                if source:
                    failure_sources.append(str(source))
        source_text = (
            f" Failed sources: {', '.join(sorted(set(failure_sources)))}."
            if failure_sources
            else ""
        )
        if state != "ready":
            return (
                f"- memory_status/{state}: {message}{source_text} "
                "If memory status is degraded, say memory search is temporarily "
                "unavailable instead of claiming nothing was found."
            )
        return self._chat_search_status_line(status)

    def _chat_search_status_line(self, status: dict) -> Optional[str]:
        source_statuses = status.get("source_statuses")
        if not isinstance(source_statuses, list):
            return None

        for source_status in source_statuses:
            if not isinstance(source_status, dict):
                continue
            if source_status.get("source") != "chat_search":
                continue
            if source_status.get("attempted") is not True:
                return None
            if source_status.get("succeeded") is not True:
                return (
                    "- chat_search_status/degraded: old chat search was attempted "
                    "but is unavailable. Say chat search is temporarily unavailable "
                    "instead of claiming nothing was found."
                )
            if source_status.get("partial") is True:
                return (
                    "- chat_search_status/partial: old chat search ran but may be "
                    "incomplete. Do not claim the user never mentioned something."
                )

            result_count = int(source_status.get("result_count") or 0)
            raw_match_count = int(source_status.get("raw_match_count") or 0)
            if result_count > 0:
                return (
                    "- chat_search_status/found: old chat search found "
                    f"{result_count} relevant conversation result(s). Use the "
                    "Relevant chat search results section as chat history, not saved "
                    "memory."
                )
            return (
                "- chat_search_status/empty: old chat search ran across saved chat "
                f"history and found no relevant conversation results "
                f"({raw_match_count} raw message match(es)). If answering no, say "
                "you searched saved memory and old chats but could not find "
                "anything about that."
            )
        return None

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

"""Why a finance change the brain asked for did not become a confirm card.

Silence is the failure mode that breaks the Truth Rule: Grok says it will move a
transaction or rename a category, the body cannot build the action, and the user
watches nothing happen. Every finance mutate therefore ends as a proposal or as
one of these reasons, which the turn speaks out loud.
"""

from __future__ import annotations

from dataclasses import dataclass, field

FINANCE_EDITS_DISABLED = "finance_edits_disabled"
UNRESOLVED_TARGET = "unresolved_target"

_REASON_TEXT = {
    FINANCE_EDITS_DISABLED: (
        "I can't change your categories, budgets, or transactions while finance "
        "edits are turned off. Turn them on in Companion settings and ask me "
        "again."
    ),
    UNRESOLVED_TARGET: (
        "I couldn't match that to a category, budget, or transaction Clarity "
        "sent me this turn, so nothing there is prepared. Name the exact "
        "category or transaction and I'll get it ready for you to confirm."
    ),
}


@dataclass(frozen=True)
class FinanceMutateOutcome:
    """Confirmable proposals plus the reasons other requested changes fell out."""

    proposals: list[dict] = field(default_factory=list)
    blocked_reasons: tuple[str, ...] = ()

    @property
    def has_blocked_changes(self) -> bool:
        return bool(self.blocked_reasons)

    def blocked_message(self) -> str:
        """One honest sentence per distinct reason, in the order they occurred."""
        lines = [
            _REASON_TEXT[reason]
            for reason in self.blocked_reasons
            if reason in _REASON_TEXT
        ]
        return " ".join(dict.fromkeys(lines))

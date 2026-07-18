"""Stream filter that hides fenced action blocks (clarity_action / rex_action)."""

from __future__ import annotations


class ActionFenceStreamFilter:
    """Hide one or more ```fence_name``` blocks while streaming."""

    end_marker = "```"

    def __init__(self, markers: tuple[str, ...] = ("```clarity_action", "```rex_action")) -> None:
        self._markers = tuple(m.lower() for m in markers)
        self._buffer = ""
        self._inside = False
        self._active_marker = ""

    def feed(self, token: str) -> list[str]:
        self._buffer += token
        visible: list[str] = []
        while self._buffer:
            if self._inside:
                end_index = self._buffer.find(self.end_marker)
                if end_index == -1:
                    keep = self._suffix_prefix_length(self._buffer, self.end_marker)
                    self._buffer = self._buffer[-keep:] if keep else ""
                    break
                self._buffer = self._buffer[end_index + len(self.end_marker) :]
                self._inside = False
                self._active_marker = ""
                continue

            hit = self._earliest_marker(self._buffer)
            if hit is not None:
                marker_index, marker = hit
                if marker_index > 0:
                    visible.append(self._buffer[:marker_index])
                self._buffer = self._buffer[marker_index + len(marker) :]
                self._inside = True
                self._active_marker = marker
                continue

            keep = self._max_partial_marker_suffix(self._buffer)
            emit_length = len(self._buffer) - keep
            if emit_length > 0:
                visible.append(self._buffer[:emit_length])
                self._buffer = self._buffer[emit_length:]
            break
        return visible

    def finish(self) -> list[str]:
        if self._inside:
            self._buffer = ""
            return []
        if not self._buffer:
            return []
        visible = [self._buffer]
        self._buffer = ""
        return visible

    def _earliest_marker(self, text: str) -> tuple[int, str] | None:
        lowered = text.lower()
        best: tuple[int, str] | None = None
        for marker in self._markers:
            index = lowered.find(marker)
            if index < 0:
                continue
            if best is None or index < best[0]:
                best = (index, marker)
        return best

    def _max_partial_marker_suffix(self, text: str) -> int:
        lowered = text.lower()
        keep = 0
        for marker in self._markers:
            keep = max(keep, self._suffix_prefix_length(lowered, marker))
        return keep

    def _suffix_prefix_length(self, value: str, prefix: str) -> int:
        max_length = min(len(value), len(prefix) - 1)
        for length in range(max_length, 0, -1):
            if prefix.startswith(value[-length:]):
                return length
        return 0

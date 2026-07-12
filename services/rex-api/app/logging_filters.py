"""Access-log redaction for secrets that may appear in query strings."""

from __future__ import annotations

import logging
import re
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

_SENSITIVE_QUERY_KEYS = frozenset(
    {
        "access_token",
        "token",
        "ticket",
        "authorization",
        "api_key",
        "apikey",
    }
)

# uvicorn access lines look like: 'GET /voice/stream?access_token=... HTTP/1.1'
_REQUEST_LINE_RE = re.compile(
    r'^(?P<prefix>.*")(?P<method>[A-Z]+)\s+(?P<path>[^\s"]+)(?P<suffix>\s+HTTP/[^"]*".*)$'
)


def redact_sensitive_query(path_with_query: str) -> str:
    if "?" not in path_with_query:
        return path_with_query
    split = urlsplit(path_with_query)
    if not split.query:
        return path_with_query
    redacted = []
    for key, value in parse_qsl(split.query, keep_blank_values=True):
        if key.lower() in _SENSITIVE_QUERY_KEYS:
            redacted.append((key, "[redacted]"))
        else:
            redacted.append((key, value))
    return urlunsplit(
        (split.scheme, split.netloc, split.path, urlencode(redacted), split.fragment)
    )


class SensitiveQueryLogFilter(logging.Filter):
    """Strip JWTs / tickets from uvicorn and app access log lines."""

    def filter(self, record: logging.LogRecord) -> bool:
        try:
            message = record.getMessage()
        except Exception:
            return True
        match = _REQUEST_LINE_RE.match(message)
        if match is None:
            if "access_token=" in message or "ticket=" in message:
                record.msg = redact_sensitive_query(message)
                record.args = ()
            return True
        path = match.group("path")
        safe_path = redact_sensitive_query(path)
        if safe_path != path:
            record.msg = (
                f"{match.group('prefix')}{match.group('method')} "
                f"{safe_path}{match.group('suffix')}"
            )
            record.args = ()
        return True


def install_sensitive_query_log_filters() -> None:
    log_filter = SensitiveQueryLogFilter()
    for logger_name in ("uvicorn.access", "uvicorn", "uvicorn.error"):
        logging.getLogger(logger_name).addFilter(log_filter)

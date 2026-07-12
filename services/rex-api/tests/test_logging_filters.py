"""Tests for access-log redaction of sensitive query params."""

from app.logging_filters import SensitiveQueryLogFilter, redact_sensitive_query


def test_redact_access_token_in_query():
    redacted = redact_sensitive_query(
        "/voice/stream?access_token=super-secret&client=web"
    )
    assert "super-secret" not in redacted
    assert "access_token=" in redacted
    assert "client=web" in redacted


def test_redact_ticket_in_query():
    redacted = redact_sensitive_query("/voice/stream?ticket=abc123")
    assert "abc123" not in redacted
    assert "redacted" in redacted


def test_sensitive_query_log_filter_rewrites_uvicorn_style_lines():
    class Record:
        def __init__(self) -> None:
            self.msg = (
                '127.0.0.1:123 - "GET /voice/stream?access_token=jwt-here HTTP/1.1" 101'
            )
            self.args = ()

        def getMessage(self) -> str:
            return self.msg

    record = Record()
    assert SensitiveQueryLogFilter().filter(record) is True
    assert "jwt-here" not in record.msg
    assert "redacted" in record.msg

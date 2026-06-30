from app.models.pagination import (
    decode_offset_cursor,
    encode_offset_cursor,
    paginate_rows,
)


def test_encode_decode_offset_cursor_round_trip():
    token = encode_offset_cursor(50)
    assert decode_offset_cursor(token) == 50


def test_paginate_rows_reports_next_page():
    rows = [{"id": str(index)} for index in range(3)]
    items, next_cursor, has_more = paginate_rows(rows, limit=2, offset=0)

    assert len(items) == 2
    assert has_more is True
    assert next_cursor is not None
    assert decode_offset_cursor(next_cursor) == 2


def test_paginate_rows_without_more_pages():
    rows = [{"id": "only"}]
    items, next_cursor, has_more = paginate_rows(rows, limit=2, offset=0)

    assert items == rows
    assert has_more is False
    assert next_cursor is None

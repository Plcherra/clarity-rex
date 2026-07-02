class MemoryServiceError(Exception):
    def __init__(
        self,
        detail: str,
        status_code: int = 503,
        *,
        error_code: str | None = None,
    ) -> None:
        super().__init__(detail)
        self.detail = detail
        self.status_code = status_code
        self.error_code = error_code

    def http_detail(self) -> str | dict[str, str]:
        if self.error_code is None:
            return self.detail
        return {"message": self.detail, "error_code": self.error_code}

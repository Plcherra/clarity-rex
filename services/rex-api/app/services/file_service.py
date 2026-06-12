import base64
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from fastapi import HTTPException, UploadFile


@dataclass(frozen=True)
class AttachmentContext:
    kind: str
    filename: str
    content_type: str
    text: Optional[str] = None
    data_url: Optional[str] = None

    @property
    def prompt_context(self) -> Optional[str]:
        if self.kind == "text":
            return self.text
        if self.kind == "image":
            return (
                f"Image attachment: {self.filename} ({self.content_type}). "
                "Use the attached image as visual context when answering."
            )
        return None


class FileService:
    max_text_file_size_bytes = 2 * 1024 * 1024
    max_image_file_size_bytes = 5 * 1024 * 1024
    supported_text_extensions = {".txt", ".md", ".csv"}
    supported_image_extensions = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
    }

    async def read_text_file(self, file: UploadFile) -> str:
        attachment = await self.read_attachment(file)
        if attachment.kind != "text" or attachment.text is None:
            raise HTTPException(
                status_code=400,
                detail="Only .txt, .md, and .csv files are supported here.",
            )
        return attachment.text

    async def read_attachment(self, file: UploadFile) -> AttachmentContext:
        extension = Path(file.filename or "").suffix.lower()
        if extension in self.supported_text_extensions:
            return await self._read_text_attachment(file, extension)
        if extension in self.supported_image_extensions:
            return await self._read_image_attachment(file, extension)

        supported = ".txt, .md, .csv, .jpg, .jpeg, .png, or .webp"
        raise HTTPException(
            status_code=400,
            detail=f"Only {supported} files are supported.",
        )

    async def _read_text_attachment(
        self,
        file: UploadFile,
        extension: str,
    ) -> AttachmentContext:
        content = await file.read()
        if len(content) > self.max_text_file_size_bytes:
            raise HTTPException(
                status_code=413,
                detail="Uploaded file is too large. Maximum size is 2MB.",
            )

        try:
            text = self._clean_text(content.decode("utf-8"))
        except UnicodeDecodeError as error:
            raise HTTPException(
                status_code=400,
                detail="Uploaded file must be valid UTF-8 text.",
            ) from error

        content_type = self._content_type(
            file,
            fallback={
                ".txt": "text/plain",
                ".md": "text/markdown",
                ".csv": "text/csv",
            }.get(extension, "text/plain"),
        )
        return AttachmentContext(
            kind="text",
            filename=file.filename or f"attachment{extension}",
            content_type=content_type,
            text=text,
        )

    async def _read_image_attachment(
        self,
        file: UploadFile,
        extension: str,
    ) -> AttachmentContext:
        content = await file.read()
        if len(content) > self.max_image_file_size_bytes:
            raise HTTPException(
                status_code=413,
                detail="Uploaded image is too large. Maximum size is 5MB.",
            )

        expected_content_type = self.supported_image_extensions[extension]
        content_type = self._content_type(file, fallback=expected_content_type)
        if content_type not in set(self.supported_image_extensions.values()):
            raise HTTPException(
                status_code=400,
                detail="Uploaded image must be a JPG, PNG, or WEBP file.",
            )

        encoded = base64.b64encode(content).decode("ascii")
        return AttachmentContext(
            kind="image",
            filename=file.filename or f"attachment{extension}",
            content_type=content_type,
            data_url=f"data:{content_type};base64,{encoded}",
        )

    def _content_type(self, file: UploadFile, *, fallback: str) -> str:
        content_type = str(getattr(file, "content_type", "") or "").lower()
        if content_type and content_type != "application/octet-stream":
            return content_type
        return fallback

    def _clean_text(self, text: str) -> str:
        return text.replace("\r\n", "\n").replace("\r", "\n").strip()

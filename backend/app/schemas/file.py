from pydantic import BaseModel, field_validator
from datetime import datetime


ALLOWED_EXTENSIONS = {"py", "md", "swift"}


class FileCreate(BaseModel):
    filename: str
    content: str = ""
    folder: str = ""
    path: str = ""

    @field_validator("filename")
    @classmethod
    def validate_extension(cls, v: str) -> str:
        ext = v.rsplit(".", 1)[-1].lower() if "." in v else ""
        if ext not in ALLOWED_EXTENSIONS:
            raise ValueError(f"File must be .py, .md, or .swift")
        return v


class FileUpdate(BaseModel):
    filename: str | None = None
    content: str | None = None
    folder: str | None = None
    path: str | None = None

    @field_validator("filename")
    @classmethod
    def validate_extension(cls, v: str | None) -> str | None:
        if v is None:
            return v
        ext = v.rsplit(".", 1)[-1].lower() if "." in v else ""
        if ext not in ALLOWED_EXTENSIONS:
            raise ValueError(f"File must be .py, .md, or .swift")
        return v


class FileResponse(BaseModel):
    id: int
    user_id: int
    filename: str
    extension: str
    content: str
    folder: str
    path: str
    size_bytes: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class FileListResponse(BaseModel):
    id: int
    filename: str
    extension: str
    folder: str
    path: str
    size_bytes: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

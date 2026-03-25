from pydantic import BaseModel, field_validator
from datetime import datetime


class MemoryCreate(BaseModel):
    content: str

    @field_validator("content")
    @classmethod
    def validate_content(cls, v: str) -> str:
        if len(v) < 1:
            raise ValueError("Content must be at least 1 character")
        if len(v) > 2000:
            raise ValueError("Content must be at most 2000 characters")
        return v


class MemoryOut(BaseModel):
    id: int
    content: str
    created_at: datetime

    model_config = {"from_attributes": True}

from pydantic import BaseModel, computed_field
from datetime import datetime


class NoteCreate(BaseModel):
    title: str
    content: str = ""


class NoteUpdate(BaseModel):
    title: str | None = None
    content: str | None = None


class NoteResponse(BaseModel):
    id: int
    user_id: int
    title: str
    content: str
    created_at: datetime
    updated_at: datetime

    @computed_field
    @property
    def preview(self) -> str | None:
        if not self.content:
            return None
        return self.content[:100]

    model_config = {"from_attributes": True}


class NoteListResponse(BaseModel):
    id: int
    title: str
    content: str
    created_at: datetime
    updated_at: datetime

    @computed_field
    @property
    def preview(self) -> str | None:
        return self.content[:100] if self.content else None

    model_config = {"from_attributes": True}

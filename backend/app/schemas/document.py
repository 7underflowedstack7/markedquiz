from pydantic import BaseModel
from datetime import datetime


class DocumentCreate(BaseModel):
    title: str
    content: str


class DocumentResponse(BaseModel):
    id: int
    title: str
    content: str
    created_at: datetime

    model_config = {"from_attributes": True}


class DocumentListItem(BaseModel):
    id: int
    title: str
    word_count: int
    created_at: datetime

    model_config = {"from_attributes": True}

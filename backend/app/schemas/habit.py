from pydantic import BaseModel, field_validator
from datetime import datetime


ALLOWED_COLORS = {"teal", "ochre", "lichen", "warm", "cool"}
ALLOWED_FREQUENCIES = {"daily", "weekly", "weekdays", "weekends"}


class HabitCreate(BaseModel):
    title: str
    description: str = ""
    icon: str = "flame.fill"
    color: str = "teal"
    frequency: str = "daily"

    @field_validator("color")
    @classmethod
    def validate_color(cls, v: str) -> str:
        if v not in ALLOWED_COLORS:
            raise ValueError(f"Color must be one of: {', '.join(sorted(ALLOWED_COLORS))}")
        return v

    @field_validator("frequency")
    @classmethod
    def validate_frequency(cls, v: str) -> str:
        if v not in ALLOWED_FREQUENCIES:
            raise ValueError(f"Frequency must be one of: {', '.join(sorted(ALLOWED_FREQUENCIES))}")
        return v


class HabitUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    icon: str | None = None
    color: str | None = None
    frequency: str | None = None

    @field_validator("color")
    @classmethod
    def validate_color(cls, v: str | None) -> str | None:
        if v is not None and v not in ALLOWED_COLORS:
            raise ValueError(f"Color must be one of: {', '.join(sorted(ALLOWED_COLORS))}")
        return v

    @field_validator("frequency")
    @classmethod
    def validate_frequency(cls, v: str | None) -> str | None:
        if v is not None and v not in ALLOWED_FREQUENCIES:
            raise ValueError(f"Frequency must be one of: {', '.join(sorted(ALLOWED_FREQUENCIES))}")
        return v


class HabitResponse(BaseModel):
    id: int
    user_id: int
    title: str
    description: str
    icon: str
    color: str
    frequency: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class EntryToggle(BaseModel):
    date: str

    @field_validator("date")
    @classmethod
    def validate_date_format(cls, v: str) -> str:
        if len(v) != 10 or v[4] != "-" or v[7] != "-":
            raise ValueError("Date must be in yyyy-MM-dd format")
        parts = v.split("-")
        if not all(p.isdigit() for p in parts):
            raise ValueError("Date must be in yyyy-MM-dd format")
        return v


class EntryResponse(BaseModel):
    id: int
    user_id: int
    habit_id: int
    date: str
    completed: bool

    model_config = {"from_attributes": True}


class StreakResponse(BaseModel):
    habit_id: int
    streak: int

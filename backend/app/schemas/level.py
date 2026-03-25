from datetime import datetime
from pydantic import BaseModel, field_validator

VALID_SOURCES = {"quiz", "habit", "pomodoro", "goal"}
VALID_GOAL_TYPES = {"custom", "level", "xp", "streak"}


class XPAward(BaseModel):
    source: str  # "quiz", "habit", "pomodoro", "goal"
    amount: int
    description: str | None = None

    @field_validator("source")
    @classmethod
    def validate_source(cls, v: str) -> str:
        if v not in VALID_SOURCES:
            raise ValueError(f"source must be one of: {', '.join(sorted(VALID_SOURCES))}")
        return v


class GoalUpdate(BaseModel):
    goal_text: str | None = None
    goal_target: int | None = None
    goal_current: int | None = None
    goal_type: str | None = None  # "custom", "level", "xp", "streak"

    @field_validator("goal_type")
    @classmethod
    def validate_goal_type(cls, v: str | None) -> str | None:
        if v is not None and v not in VALID_GOAL_TYPES:
            raise ValueError(f"goal_type must be one of: {', '.join(sorted(VALID_GOAL_TYPES))}")
        return v


class XPEventResponse(BaseModel):
    id: int
    xp_amount: int
    source: str
    description: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class LevelResponse(BaseModel):
    total_xp: int
    level: int
    xp_for_next_level: int  # computed: level * 100
    xp_in_current_level: int  # computed: total_xp - sum of previous levels
    goal_text: str | None
    goal_target: int | None
    goal_current: int
    goal_type: str | None

    model_config = {"from_attributes": True}

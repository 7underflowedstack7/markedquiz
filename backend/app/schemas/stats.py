from pydantic import BaseModel
from datetime import date
from typing import Optional


class StatsResponse(BaseModel):
    total_xp: int
    level: int
    xp_for_next_level: int
    xp_progress_in_level: int
    quizzes_completed: int
    streak_days: int
    best_streak: int
    average_score: float
    last_active: Optional[date]


class SubjectStat(BaseModel):
    document_title: str
    attempts: int
    best_score: float
    average_score: float
    total_xp: int


class SubjectStatsResponse(BaseModel):
    subjects: list[SubjectStat]


class ScoreHistoryItem(BaseModel):
    date: str
    score: float
    document_title: str


class ScoreHistoryResponse(BaseModel):
    history: list[ScoreHistoryItem]

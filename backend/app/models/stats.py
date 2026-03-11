from sqlalchemy import Column, Integer, DateTime, Date
from sqlalchemy.sql import func
from app.database import Base


class UserStats(Base):
    __tablename__ = "user_stats"

    id = Column(Integer, primary_key=True, default=1)
    total_xp = Column(Integer, nullable=False, default=0)
    quizzes_completed = Column(Integer, nullable=False, default=0)
    streak_days = Column(Integer, nullable=False, default=0)
    best_streak = Column(Integer, nullable=False, default=0)
    last_active = Column(Date, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

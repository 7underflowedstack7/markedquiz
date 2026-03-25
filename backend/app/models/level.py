from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, func
from app.database import Base


class UserLevel(Base):
    __tablename__ = "user_levels"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    total_xp = Column(Integer, default=0, nullable=False)
    level = Column(Integer, default=1, nullable=False)
    goal_text = Column(String, nullable=True)
    goal_target = Column(Integer, nullable=True)
    goal_current = Column(Integer, default=0, nullable=False)
    goal_type = Column(String, nullable=True)  # "custom", "level", "xp", "streak"
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class XPEvent(Base):
    __tablename__ = "xp_events"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    xp_amount = Column(Integer, nullable=False)
    source = Column(String, nullable=False)  # "quiz", "habit", "pomodoro", "goal"
    description = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

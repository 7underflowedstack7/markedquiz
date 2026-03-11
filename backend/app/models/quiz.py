from sqlalchemy import Column, Integer, String, Text, DateTime, Float, ForeignKey, JSON
from sqlalchemy.sql import func
from app.database import Base


class Quiz(Base):
    __tablename__ = "quizzes"

    id = Column(Integer, primary_key=True, index=True)
    document_id = Column(Integer, ForeignKey("documents.id", ondelete="CASCADE"), nullable=False)
    title = Column(String(255), nullable=False)
    questions = Column(JSON, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class QuizAttempt(Base):
    __tablename__ = "quiz_attempts"

    id = Column(Integer, primary_key=True, index=True)
    quiz_id = Column(Integer, ForeignKey("quizzes.id", ondelete="CASCADE"), nullable=False)
    document_title = Column(String(255), nullable=False, default="")
    score = Column(Integer, nullable=False)
    total = Column(Integer, nullable=False)
    percentage = Column(Float, nullable=False)
    answers = Column(JSON, nullable=False)
    xp_earned = Column(Integer, nullable=False, default=0)
    completed_at = Column(DateTime(timezone=True), server_default=func.now())

from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class QuestionOption(BaseModel):
    id: str
    text: str


class Question(BaseModel):
    id: str
    type: str  # "free_response", "multiple_choice", "true_false", "fill_blank"
    question: str
    options: list[QuestionOption]
    correct_answer: str
    keywords: list[str] = []
    explanation: str
    source_section: str


class QuizResponse(BaseModel):
    id: int
    document_id: int
    title: str
    questions: list[Question]
    created_at: datetime

    model_config = {"from_attributes": True}


class AnswerSubmission(BaseModel):
    question_id: str
    user_answer: str


class QuizSubmission(BaseModel):
    answers: list[AnswerSubmission]


class AnswerResult(BaseModel):
    question_id: str
    question: str
    user_answer: str
    correct_answer: str
    is_correct: bool
    explanation: str


class QuizResult(BaseModel):
    quiz_id: int
    score: int
    total: int
    percentage: float
    xp_earned: int
    results: list[AnswerResult]


class QuizAttemptResponse(BaseModel):
    id: int
    quiz_id: int
    document_title: str
    score: int
    total: int
    percentage: float
    xp_earned: int
    completed_at: datetime

    model_config = {"from_attributes": True}

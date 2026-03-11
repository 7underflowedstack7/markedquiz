from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.document import Document
from app.models.quiz import Quiz, QuizAttempt
from app.models.stats import UserStats
from app.schemas.quiz import QuizResponse, QuizSubmission, QuizResult, AnswerResult, QuizAttemptResponse
from app.services.quiz_generator import generate_quiz
from app.services.stats_service import calculate_xp
from datetime import date

router = APIRouter(prefix="/api", tags=["quizzes"])


@router.post("/documents/{document_id}/quiz", response_model=QuizResponse)
async def create_quiz(document_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Document).where(Document.id == document_id))
    doc = result.scalar_one_or_none()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    questions = generate_quiz(doc.title, doc.content, max_questions=10)

    if not questions:
        raise HTTPException(
            status_code=422,
            detail="Could not generate questions from this document. Try a longer or more structured markdown file."
        )

    quiz = Quiz(
        document_id=doc.id,
        title=f"Quiz: {doc.title}",
        questions=questions,
    )
    db.add(quiz)
    await db.commit()
    await db.refresh(quiz)
    return quiz


@router.get("/quizzes/{quiz_id}", response_model=QuizResponse)
async def get_quiz(quiz_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Quiz).where(Quiz.id == quiz_id))
    quiz = result.scalar_one_or_none()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")
    return quiz


@router.post("/quizzes/{quiz_id}/submit", response_model=QuizResult)
async def submit_quiz(quiz_id: int, submission: QuizSubmission, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Quiz).where(Quiz.id == quiz_id))
    quiz = result.scalar_one_or_none()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")

    # Get document title for tracking
    doc_result = await db.execute(select(Document).where(Document.id == quiz.document_id))
    doc = doc_result.scalar_one_or_none()
    doc_title = doc.title if doc else "Unknown"

    # Build answer map
    answer_map = {a.question_id: a.user_answer for a in submission.answers}

    results = []
    score = 0
    total = len(quiz.questions)

    for q in quiz.questions:
        user_answer = answer_map.get(q["id"], "")
        correct_answer = q["correct_answer"]

        # For fill_blank, do case-insensitive comparison
        if q["type"] == "fill_blank":
            is_correct = user_answer.strip().lower() == correct_answer.strip().lower()
        else:
            is_correct = user_answer == correct_answer

        if is_correct:
            score += 1

        results.append(AnswerResult(
            question_id=q["id"],
            question=q["question"],
            user_answer=user_answer,
            correct_answer=correct_answer,
            is_correct=is_correct,
            explanation=q["explanation"],
        ))

    percentage = (score / total * 100) if total > 0 else 0
    xp_earned = calculate_xp(score, total)

    # Save attempt
    attempt = QuizAttempt(
        quiz_id=quiz_id,
        document_title=doc_title,
        score=score,
        total=total,
        percentage=percentage,
        answers=[{"question_id": r.question_id, "user_answer": r.user_answer, "is_correct": r.is_correct} for r in results],
        xp_earned=xp_earned,
    )
    db.add(attempt)

    # Update stats
    stats_result = await db.execute(select(UserStats).where(UserStats.id == 1))
    stats = stats_result.scalar_one_or_none()

    today = date.today()

    if not stats:
        stats = UserStats(
            id=1,
            total_xp=xp_earned,
            quizzes_completed=1,
            streak_days=1,
            best_streak=1,
            last_active=today,
        )
        db.add(stats)
    else:
        stats.total_xp += xp_earned
        stats.quizzes_completed += 1

        if stats.last_active:
            diff = (today - stats.last_active).days
            if diff == 1:
                stats.streak_days += 1
            elif diff > 1:
                stats.streak_days = 1
            # diff == 0: same day, no change
        else:
            stats.streak_days = 1

        stats.best_streak = max(stats.best_streak, stats.streak_days)
        stats.last_active = today

    await db.commit()

    return QuizResult(
        quiz_id=quiz_id,
        score=score,
        total=total,
        percentage=percentage,
        xp_earned=xp_earned,
        results=results,
    )


@router.get("/attempts", response_model=list[QuizAttemptResponse])
async def list_attempts(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(QuizAttempt).order_by(QuizAttempt.completed_at.desc()).limit(50))
    return result.scalars().all()

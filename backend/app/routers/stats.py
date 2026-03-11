from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.database import get_db
from app.models.quiz import QuizAttempt
from app.models.stats import UserStats
from app.schemas.stats import StatsResponse, SubjectStatsResponse, SubjectStat, ScoreHistoryResponse, ScoreHistoryItem
from app.services.stats_service import level_from_xp, xp_for_level

router = APIRouter(prefix="/api/stats", tags=["stats"])


@router.get("", response_model=StatsResponse)
async def get_stats(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(UserStats).where(UserStats.id == 1))
    stats = result.scalar_one_or_none()

    if not stats:
        return StatsResponse(
            total_xp=0,
            level=1,
            xp_for_next_level=xp_for_level(2),
            xp_progress_in_level=0,
            quizzes_completed=0,
            streak_days=0,
            best_streak=0,
            average_score=0.0,
            last_active=None,
        )

    level = level_from_xp(stats.total_xp)
    next_level_xp = xp_for_level(level + 1)
    current_level_xp = xp_for_level(level)

    # Average score
    avg_result = await db.execute(select(func.avg(QuizAttempt.percentage)))
    avg_score = avg_result.scalar() or 0.0

    return StatsResponse(
        total_xp=stats.total_xp,
        level=level,
        xp_for_next_level=next_level_xp - current_level_xp,
        xp_progress_in_level=stats.total_xp - current_level_xp,
        quizzes_completed=stats.quizzes_completed,
        streak_days=stats.streak_days,
        best_streak=stats.best_streak,
        average_score=round(avg_score, 1),
        last_active=stats.last_active,
    )


@router.get("/subjects", response_model=SubjectStatsResponse)
async def get_subject_stats(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(
            QuizAttempt.document_title,
            func.count(QuizAttempt.id).label("attempts"),
            func.max(QuizAttempt.percentage).label("best_score"),
            func.avg(QuizAttempt.percentage).label("average_score"),
            func.sum(QuizAttempt.xp_earned).label("total_xp"),
        )
        .group_by(QuizAttempt.document_title)
        .order_by(func.count(QuizAttempt.id).desc())
    )

    subjects = []
    for row in result.all():
        subjects.append(SubjectStat(
            document_title=row.document_title,
            attempts=row.attempts,
            best_score=round(row.best_score, 1),
            average_score=round(row.average_score, 1),
            total_xp=row.total_xp or 0,
        ))

    return SubjectStatsResponse(subjects=subjects)


@router.get("/history", response_model=ScoreHistoryResponse)
async def get_score_history(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(QuizAttempt)
        .order_by(QuizAttempt.completed_at.desc())
        .limit(30)
    )
    attempts = result.scalars().all()

    history = [
        ScoreHistoryItem(
            date=a.completed_at.strftime("%Y-%m-%d") if a.completed_at else "",
            score=round(a.percentage, 1),
            document_title=a.document_title,
        )
        for a in reversed(attempts)
    ]

    return ScoreHistoryResponse(history=history)

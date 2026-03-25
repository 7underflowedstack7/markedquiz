from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.level import UserLevel, XPEvent
from app.schemas.level import XPAward, GoalUpdate, XPEventResponse, LevelResponse
from app.auth.models import User
from app.auth.dependencies import get_current_user

router = APIRouter()


def _cumulative_xp_for_level(level: int) -> int:
    """Total XP needed to reach a given level.

    XP needed for level N = N * 100.
    Total XP to reach level N = sum(1..N-1) * 100 = N*(N-1)/2 * 100.
    """
    return level * (level - 1) // 2 * 100


def _calculate_level(total_xp: int) -> int:
    """Determine the level for a given total XP amount."""
    level = 1
    while _cumulative_xp_for_level(level + 1) <= total_xp:
        level += 1
    return level


def _build_level_response(user_level: UserLevel) -> LevelResponse:
    """Build a LevelResponse with computed fields from a UserLevel row."""
    level = user_level.level
    xp_for_next = level * 100
    xp_in_current = user_level.total_xp - _cumulative_xp_for_level(level)
    return LevelResponse(
        total_xp=user_level.total_xp,
        level=level,
        xp_for_next_level=xp_for_next,
        xp_in_current_level=xp_in_current,
        goal_text=user_level.goal_text,
        goal_target=user_level.goal_target,
        goal_current=user_level.goal_current,
        goal_type=user_level.goal_type,
    )


async def _get_or_create_user_level(user_id: int, db: AsyncSession) -> UserLevel:
    """Fetch the UserLevel row for a user, creating one if it doesn't exist."""
    result = await db.execute(
        select(UserLevel).where(UserLevel.user_id == user_id)
    )
    user_level = result.scalar_one_or_none()
    if not user_level:
        user_level = UserLevel(user_id=user_id, total_xp=0, level=1, goal_current=0)
        db.add(user_level)
        await db.commit()
        await db.refresh(user_level)
    return user_level


@router.get("", response_model=LevelResponse)
async def get_level(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user_level = await _get_or_create_user_level(current_user.id, db)
    return _build_level_response(user_level)


@router.post("/xp", response_model=LevelResponse)
async def award_xp(
    data: XPAward,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if data.amount <= 0:
        raise HTTPException(status_code=422, detail="XP amount must be positive")

    user_level = await _get_or_create_user_level(current_user.id, db)

    # Add XP and recalculate level
    user_level.total_xp += data.amount
    user_level.level = _calculate_level(user_level.total_xp)

    # Create audit event
    event = XPEvent(
        user_id=current_user.id,
        xp_amount=data.amount,
        source=data.source,
        description=data.description,
    )
    db.add(event)

    await db.commit()
    await db.refresh(user_level)
    return _build_level_response(user_level)


@router.put("/goal", response_model=LevelResponse)
async def update_goal(
    data: GoalUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user_level = await _get_or_create_user_level(current_user.id, db)

    if data.goal_text is not None:
        user_level.goal_text = data.goal_text
    if data.goal_target is not None:
        user_level.goal_target = data.goal_target
    if data.goal_current is not None:
        user_level.goal_current = data.goal_current
    if data.goal_type is not None:
        user_level.goal_type = data.goal_type

    await db.commit()
    await db.refresh(user_level)
    return _build_level_response(user_level)


@router.get("/history", response_model=list[XPEventResponse])
async def xp_history(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(XPEvent)
        .where(XPEvent.user_id == current_user.id)
        .order_by(XPEvent.created_at.desc())
        .limit(20)
    )
    return result.scalars().all()

from datetime import date, timedelta
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from app.database import get_db
from app.models.habit import Habit, HabitEntry
from app.schemas.habit import (
    HabitCreate, HabitUpdate, HabitResponse,
    EntryToggle, EntryResponse, StreakResponse,
)
from app.auth.models import User
from app.auth.dependencies import get_current_user

router = APIRouter()


# --- Habits CRUD ---

@router.get("", response_model=list[HabitResponse])
async def list_habits(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Habit)
        .where(Habit.user_id == current_user.id)
        .order_by(Habit.created_at.asc())
    )
    return result.scalars().all()


@router.get("/{habit_id}", response_model=HabitResponse)
async def get_habit(
    habit_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    habit = await _get_user_habit(habit_id, current_user.id, db)
    return habit


@router.post("", response_model=HabitResponse, status_code=201)
async def create_habit(
    data: HabitCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    habit = Habit(
        user_id=current_user.id,
        title=data.title,
        description=data.description,
        icon=data.icon,
        color=data.color,
        frequency=data.frequency,
    )
    db.add(habit)
    await db.commit()
    await db.refresh(habit)
    return habit


@router.put("/{habit_id}", response_model=HabitResponse)
async def update_habit(
    habit_id: int,
    data: HabitUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    habit = await _get_user_habit(habit_id, current_user.id, db)
    if data.title is not None:
        habit.title = data.title
    if data.description is not None:
        habit.description = data.description
    if data.icon is not None:
        habit.icon = data.icon
    if data.color is not None:
        habit.color = data.color
    if data.frequency is not None:
        habit.frequency = data.frequency
    await db.commit()
    await db.refresh(habit)
    return habit


@router.delete("/{habit_id}")
async def delete_habit(
    habit_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    habit = await _get_user_habit(habit_id, current_user.id, db)
    await db.delete(habit)
    await db.commit()
    return {"detail": "Habit deleted"}


# --- Entries ---

@router.get("/entries/list", response_model=list[EntryResponse])
async def list_entries(
    date_filter: str | None = Query(None, alias="date", description="Single date (yyyy-MM-dd)"),
    date_from: str | None = Query(None, alias="from", description="Start date inclusive"),
    date_to: str | None = Query(None, alias="to", description="End date inclusive"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(HabitEntry).where(HabitEntry.user_id == current_user.id)
    if date_filter:
        query = query.where(HabitEntry.date == date_filter)
    else:
        if date_from:
            query = query.where(HabitEntry.date >= date_from)
        if date_to:
            query = query.where(HabitEntry.date <= date_to)
    query = query.order_by(HabitEntry.date.desc())
    result = await db.execute(query)
    return result.scalars().all()


@router.post("/{habit_id}/toggle", response_model=EntryResponse)
async def toggle_entry(
    habit_id: int,
    data: EntryToggle,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Verify habit belongs to user
    await _get_user_habit(habit_id, current_user.id, db)

    # Check for existing entry
    result = await db.execute(
        select(HabitEntry).where(
            and_(
                HabitEntry.habit_id == habit_id,
                HabitEntry.user_id == current_user.id,
                HabitEntry.date == data.date,
            )
        )
    )
    entry = result.scalar_one_or_none()

    if entry:
        entry.completed = not entry.completed
    else:
        entry = HabitEntry(
            user_id=current_user.id,
            habit_id=habit_id,
            date=data.date,
            completed=True,
        )
        db.add(entry)

    await db.commit()
    await db.refresh(entry)
    return entry


@router.get("/{habit_id}/streak", response_model=StreakResponse)
async def get_streak(
    habit_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _get_user_habit(habit_id, current_user.id, db)

    # Fetch all completed entries for this habit, ordered by date desc
    result = await db.execute(
        select(HabitEntry.date)
        .where(
            and_(
                HabitEntry.habit_id == habit_id,
                HabitEntry.user_id == current_user.id,
                HabitEntry.completed.is_(True),
            )
        )
        .order_by(HabitEntry.date.desc())
    )
    completed_dates = {row[0] for row in result.fetchall()}

    streak = 0
    check_date = date.today()

    # If not completed today, start from yesterday
    if check_date.isoformat() not in completed_dates:
        check_date = check_date - timedelta(days=1)

    while check_date.isoformat() in completed_dates:
        streak += 1
        check_date = check_date - timedelta(days=1)

    return StreakResponse(habit_id=habit_id, streak=streak)


# --- Helpers ---

async def _get_user_habit(habit_id: int, user_id: int, db: AsyncSession) -> Habit:
    result = await db.execute(
        select(Habit).where(Habit.id == habit_id, Habit.user_id == user_id)
    )
    habit = result.scalar_one_or_none()
    if not habit:
        raise HTTPException(status_code=404, detail="Habit not found")
    return habit

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.memory import Memory
from app.schemas.memory import MemoryCreate, MemoryOut
from app.auth.models import User
from app.auth.dependencies import get_current_user

router = APIRouter()


@router.get("", response_model=list[MemoryOut])
async def list_memories(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Memory)
        .where(Memory.user_id == current_user.id)
        .order_by(Memory.created_at.desc())
    )
    return result.scalars().all()


@router.post("", response_model=MemoryOut, status_code=201)
async def create_memory(
    data: MemoryCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    memory = Memory(
        user_id=current_user.id,
        content=data.content,
    )
    db.add(memory)
    await db.commit()
    await db.refresh(memory)
    return memory


@router.delete("/{memory_id}", status_code=204)
async def delete_memory(
    memory_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Memory).where(Memory.id == memory_id, Memory.user_id == current_user.id)
    )
    memory = result.scalar_one_or_none()
    if not memory:
        raise HTTPException(status_code=404, detail="Memory not found")
    await db.delete(memory)
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)

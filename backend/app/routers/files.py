from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.file import File
from app.schemas.file import FileCreate, FileUpdate, FileResponse, FileListResponse
from app.auth.models import User
from app.auth.dependencies import get_current_user

router = APIRouter()


@router.get("", response_model=list[FileListResponse])
async def list_files(
    extension: str | None = Query(None, description="Filter by extension (py, md, swift, txt)"),
    folder: str | None = Query(None, description="Filter by folder"),
    path: str | None = Query(None, description="Filter by path prefix"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(File).where(File.user_id == current_user.id)
    if extension:
        query = query.where(File.extension == extension.lower().lstrip("."))
    if folder:
        query = query.where(File.folder == folder)
    if path:
        query = query.where(File.path.startswith(path))
    query = query.order_by(File.updated_at.desc())
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/{file_id}", response_model=FileResponse)
async def get_file(
    file_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(File).where(File.id == file_id, File.user_id == current_user.id)
    )
    file = result.scalar_one_or_none()
    if not file:
        raise HTTPException(status_code=404, detail="File not found")
    return file


@router.post("", response_model=FileResponse, status_code=201)
async def create_file(
    data: FileCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ext = data.filename.rsplit(".", 1)[-1].lower()
    file = File(
        user_id=current_user.id,
        filename=data.filename,
        extension=ext,
        content=data.content,
        folder=data.folder,
        path=data.path,
        size_bytes=len(data.content.encode("utf-8")),
    )
    db.add(file)
    await db.commit()
    await db.refresh(file)
    return file


@router.put("/{file_id}", response_model=FileResponse)
async def update_file(
    file_id: int,
    data: FileUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(File).where(File.id == file_id, File.user_id == current_user.id)
    )
    file = result.scalar_one_or_none()
    if not file:
        raise HTTPException(status_code=404, detail="File not found")
    if data.filename is not None:
        file.filename = data.filename
        file.extension = data.filename.rsplit(".", 1)[-1].lower()
    if data.content is not None:
        file.content = data.content
        file.size_bytes = len(data.content.encode("utf-8"))
    if data.folder is not None:
        file.folder = data.folder
    if data.path is not None:
        file.path = data.path
    await db.commit()
    await db.refresh(file)
    return file


@router.delete("/{file_id}")
async def delete_file(
    file_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(File).where(File.id == file_id, File.user_id == current_user.id)
    )
    file = result.scalar_one_or_none()
    if not file:
        raise HTTPException(status_code=404, detail="File not found")
    await db.delete(file)
    await db.commit()
    return {"detail": "File deleted"}

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.document import Document
from app.schemas.document import DocumentCreate, DocumentResponse, DocumentListItem

router = APIRouter(prefix="/api/documents", tags=["documents"])


@router.get("", response_model=list[DocumentListItem])
async def list_documents(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Document).order_by(Document.created_at.desc()))
    docs = result.scalars().all()
    return [
        DocumentListItem(
            id=doc.id,
            title=doc.title,
            word_count=len(doc.content.split()),
            created_at=doc.created_at,
        )
        for doc in docs
    ]


@router.post("", response_model=DocumentResponse)
async def create_document(doc: DocumentCreate, db: AsyncSession = Depends(get_db)):
    document = Document(title=doc.title, content=doc.content)
    db.add(document)
    await db.commit()
    await db.refresh(document)
    return document


@router.post("/upload", response_model=DocumentResponse)
async def upload_document(file: UploadFile = File(...), db: AsyncSession = Depends(get_db)):
    if not file.filename or not file.filename.endswith(".md"):
        raise HTTPException(status_code=400, detail="Only .md files are supported")

    content = await file.read()
    text = content.decode("utf-8")
    title = file.filename.replace(".md", "").replace("-", " ").replace("_", " ").title()

    document = Document(title=title, content=text)
    db.add(document)
    await db.commit()
    await db.refresh(document)
    return document


@router.get("/{document_id}", response_model=DocumentResponse)
async def get_document(document_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Document).where(Document.id == document_id))
    doc = result.scalar_one_or_none()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")
    return doc


@router.delete("/{document_id}")
async def delete_document(document_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Document).where(Document.id == document_id))
    doc = result.scalar_one_or_none()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")
    await db.delete(doc)
    await db.commit()
    return {"detail": "Document deleted"}

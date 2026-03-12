from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import init_db
from app.routers import documents, quizzes, stats, database


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield


app = FastAPI(
    title="MarkedQuiz API",
    description="Turn markdown files into interactive quizzes",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(documents.router)
app.include_router(quizzes.router)
app.include_router(stats.router)
app.include_router(database.router)


@app.get("/api/health")
async def health_check():
    return {"status": "ok", "service": "markedquiz"}

import os
import logging
import time
import uuid
from contextvars import ContextVar
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.database import init_db
from app.logging_config import setup_logging
from app.routers import notes, files
from app.auth.router import router as auth_router
from app.models.notes import Note  # noqa: F401
from app.models.file import File  # noqa: F401

try:
    from slowapi import Limiter, _rate_limit_exceeded_handler
    from slowapi.util import get_remote_address
    from slowapi.errors import RateLimitExceeded
    limiter = Limiter(key_func=get_remote_address)
    HAS_SLOWAPI = True
except ImportError:
    HAS_SLOWAPI = False

# Request ID context variable — available to all loggers in the request chain
request_id_ctx: ContextVar[str] = ContextVar("request_id", default="-")

logger = logging.getLogger("simple_db.request")


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging()
    logger.info("simple_db starting up")
    await init_db()
    yield
    logger.info("simple_db shutting down")


app = FastAPI(
    title="simple_db API",
    description="Multi-client database API",
    version="1.0.0",
    lifespan=lifespan,
)

# Rate limiting
if HAS_SLOWAPI:
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS — specific origins in production, permissive in dev
ALLOWED_ORIGINS = os.getenv(
    "ALLOWED_ORIGINS",
    "http://localhost:3000,http://localhost:8000",
).split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)


# Security headers middleware
@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    if os.getenv("RENDER"):
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return response


# Request size limit middleware (10MB)
REQUEST_MAX_SIZE = 10 * 1024 * 1024


@app.middleware("http")
async def limit_request_size(request: Request, call_next):
    # Check Content-Length header first (fast reject)
    if request.headers.get("content-length"):
        try:
            content_length = int(request.headers["content-length"])
        except ValueError:
            return JSONResponse(
                status_code=status.HTTP_400_BAD_REQUEST,
                content={"detail": "Invalid Content-Length header"},
            )
        if content_length > REQUEST_MAX_SIZE:
            return JSONResponse(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                content={"detail": "Request too large"},
            )

    # Also enforce on the actual body for chunked/missing Content-Length requests
    if request.method in ("POST", "PUT", "PATCH"):
        body = await request.body()
        if len(body) > REQUEST_MAX_SIZE:
            return JSONResponse(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                content={"detail": "Request body too large"},
            )

    return await call_next(request)


# Request logging middleware with request_id and slow query detection
SLOW_REQUEST_THRESHOLD_MS = 500


@app.middleware("http")
async def request_logging(request: Request, call_next):
    rid = uuid.uuid4().hex[:12]
    request_id_ctx.set(rid)
    start = time.perf_counter()

    response = await call_next(request)

    duration_ms = (time.perf_counter() - start) * 1000
    log_data = {
        "request_id": rid,
        "method": request.method,
        "path": request.url.path,
        "status": response.status_code,
        "duration_ms": round(duration_ms, 1),
        "client": request.client.host if request.client else "unknown",
    }

    if duration_ms > SLOW_REQUEST_THRESHOLD_MS:
        logger.warning("Slow request", extra=log_data)
    elif response.status_code >= 500:
        logger.error("Server error", extra=log_data)
    elif response.status_code >= 400:
        logger.warning("Client error", extra=log_data)
    else:
        logger.info("Request completed", extra=log_data)

    response.headers["X-Request-ID"] = rid
    return response


# Strip sensitive data from production errors
@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    rid = request_id_ctx.get("-")
    logger.error("Unhandled exception", extra={
        "request_id": rid,
        "path": request.url.path,
        "error_type": type(exc).__name__,
    })
    if os.getenv("RENDER"):
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error"},
        )
    raise exc


app.include_router(auth_router)
app.include_router(notes.router, prefix="/api/notes", tags=["notes"])
app.include_router(files.router, prefix="/api/files", tags=["files"])


@app.get("/api/health")
async def health_check():
    return {"status": "ok", "service": "simple_db"}


# --- TEMPORARY ADMIN ENDPOINT — remove after cleanup ---
from sqlalchemy import text
from app.database import get_db
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession


@app.get("/api/admin/tables")
async def list_tables(db: AsyncSession = Depends(get_db)):
    result = await db.execute(text(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema = 'public' ORDER BY table_name"
    ))
    tables = [row[0] for row in result.fetchall()]

    table_info = {}
    for table in tables:
        count = await db.execute(text(f'SELECT COUNT(*) FROM "{table}"'))
        table_info[table] = count.scalar()

    return {"tables": table_info}


@app.delete("/api/admin/tables/{table_name}")
async def drop_table(table_name: str, db: AsyncSession = Depends(get_db)):
    # Only allow dropping known deprecated tables
    allowed = {
        "documents", "quizzes", "quiz_attempts", "user_stats",
        "coffee_categories", "coffee_menu_items", "coffee_modifiers",
        "coffee_item_modifiers", "coffee_customers", "coffee_staff",
        "coffee_orders", "coffee_order_items", "coffee_points_log",
        "coffee_rewards", "coffee_redemptions", "coffee_promotions",
    }
    if table_name not in allowed:
        return {"error": f"Not allowed to drop '{table_name}'"}
    await db.execute(text(f'DROP TABLE IF EXISTS "{table_name}" CASCADE'))
    await db.commit()
    return {"dropped": table_name}

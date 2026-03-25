# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

MarkedQuiz is a personal notes and file storage app with a FastAPI backend (deployed on Render) and a SwiftUI iOS frontend. The backend provides JWT-authenticated REST APIs for notes and file CRUD, while the frontend is a dark-mode Notes app with biometric lock, file browsing, and folder organization.

**Live URL:** `https://markedquiz.onrender.com/`

## Backend

### Setup & Commands

```bash
cd backend
source .venv/bin/activate        # Python 3.12.3
pip install -r requirements.txt  # production deps
pip install -r requirements-dev.txt  # adds pytest, aiosqlite

# Run locally
python run.py                    # uvicorn on port 8000 with --reload

# Tests (uses in-memory SQLite via aiosqlite)
pytest tests/ -v
pytest tests/test_auth.py -v     # single test file
pytest tests/test_auth.py::test_register -v  # single test

# Migrations
alembic upgrade head             # apply migrations
alembic revision --autogenerate -m "description"  # create migration

# Security scan (also runs as pre-commit hook)
bandit -r app/ -ll
```

### Architecture

- **`app/main.py`** — FastAPI app with CORS, security headers middleware, request logging, and rate limiting (slowapi)
- **`app/database.py`** — Async SQLAlchemy engine (asyncpg driver). Auto-converts `postgresql://` URLs to `postgresql+asyncpg://`. Local default DB: `postgresql+asyncpg://alan@localhost:5432/simple_db`
- **`app/auth/`** — Auth router + models. JWT tokens (30min access, 7-day refresh), bcrypt password hashing
- **`app/routers/files.py`** — File CRUD with folder organization. Allowed extensions: `.py`, `.md`, `.swift`
- **`app/routers/notes.py`** — Note CRUD
- **`app/models.py`** — SQLAlchemy models: `User`, `Note`, `File` (all user-scoped via `user_id` FK)
- **`app/migrations/`** — Alembic migrations directory

### API Routes

All routes prefixed with `/api/`. Auth routes at `/api/auth/` (register, login, refresh, me). Resource routes at `/api/files/` and `/api/notes/`. Health check at `/api/health`.

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | PostgreSQL connection string |
| `SECRET_KEY` | JWT signing key |
| `ALLOWED_ORIGINS` | CORS whitelist (comma-separated) |

## Frontend

- **Xcode project:** `frontend/Notes.xcodeproj`
- Pure SwiftUI, no external dependencies
- Uses `@Observable` macro for ViewModels
- All API services point to `https://markedquiz.onrender.com/api/`
- Auth tokens stored in Keychain (`KeychainHelper`)
- Biometric unlock via LocalAuthentication (Face ID / Touch ID)
- Design system in `Theme.swift` ("Earthly" palette with iron, ochre, lichen color tokens)

## CI/CD & Hooks

- **GitHub Actions** (`.github/workflows/security.yml`): pytest, Bandit SAST scan, dependency vulnerability scan
- **Pre-commit hooks**: Bandit on `backend/app/`, detect-secrets, large file check (500KB), merge conflict detection, private key detection
- **Dependabot**: Weekly pip and GitHub Actions updates
- **Render deployment**: `render.yaml` — runs `alembic upgrade head` then uvicorn on `$PORT`

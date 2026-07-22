# DeadlineTracker

A daily task tracker: recurring habits, one-off tasks with deadlines and
priority, stats on how consistently you actually do them, and a lightweight
income/savings-goal tracker. Overdue tasks turn red and sink to the bottom of
the list — but stay completable.

Four tabs: **Home** (today's progress, the most urgent task with a live
countdown, high-priority items due this week), **Tasks** (daily habits +
one-off tasks), **Statistics** (period stats, activity chart, per-habit
history, CSV export), **Finance** (mark any daily habit as "financial" to log
income when you complete it, then track it toward savings goals with a
progress ring).

Open source, built primarily for personal use, with an architecture meant to
scale to a real multi-user mobile release later (FastAPI + PostgreSQL
backend, Flutter client, JWT sessions, and personal API tokens for
third-party integrations).

## Stack

- **Backend:** FastAPI, async SQLAlchemy + PostgreSQL, Alembic
- **Mobile:** Flutter (Riverpod, go_router, dio)
- **Local dev:** Docker Compose

## Project layout

```
backend/   FastAPI service — see backend/app for source, backend/tests for tests
mobile/    Flutter app — see mobile/lib
```

## Getting started

### Backend

```bash
cp .env.example .env          # then fill in real secrets
docker compose up -d db       # Postgres on localhost:5433

cd backend
python -m venv .venv
.venv/Scripts/pip install -r requirements-dev.txt   # .venv/bin/pip on macOS/Linux
cp .env.example ../.env       # or create backend/.env with DATABASE_URL pointing at localhost:5433
python -m alembic upgrade head
python -m uvicorn app.main:app --reload
```

API docs: http://localhost:8000/docs

Run tests: `python -m pytest` (from `backend/`).

### Mobile

```bash
cd mobile
flutter pub get
flutter run
```

The API base URL defaults to `10.0.2.2:8000` on the Android emulator (which
maps to the host machine) and `localhost:8000` elsewhere — see
`mobile/lib/core/api/api_client.dart`.

### Everything via Docker

```bash
docker compose up --build
```

Starts Postgres, the FastAPI backend (with hot reload), and Adminer (DB UI)
at http://localhost:8080.

## API

All endpoints are versioned under `/api/v1`. Authentication accepts either:

- a short-lived JWT from `/api/v1/auth/login` (mobile app session), or
- a personal API token issued via `/api/v1/api-tokens` (for scripts/third-party
  integrations) — pass it the same way: `Authorization: Bearer <token>`.

## License

MIT — see [LICENSE](LICENSE).

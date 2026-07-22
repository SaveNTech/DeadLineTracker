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

The API base URL defaults to `localhost:8000` (works for the emulator with
`adb reverse tcp:8000 tcp:8000`, or a physical device the same way over USB).
Override it at build time to point at a deployed server instead — see
`mobile/lib/core/api/api_client.dart`:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-server/api/v1
```

### Everything via Docker

```bash
docker compose up --build
```

Starts Postgres and the FastAPI backend (with hot reload).

## API

All endpoints are versioned under `/api/v1`. Interactive docs (Swagger UI)
are always available at `<base-url>/docs`.

Two ways to authenticate, both via the same `Authorization: Bearer <token>`
header on every request:

- a short-lived **JWT access token** from `/api/v1/auth/login` (what the
  mobile app uses — expires in `ACCESS_TOKEN_EXPIRE_MINUTES`, refresh with
  `/api/v1/auth/refresh`), or
- a long-lived **personal API token** (`dt_live_...`) from
  `/api/v1/api-tokens` — for scripts and third-party integrations that
  shouldn't need to know a user's password or handle token refresh.

There's no web UI for managing personal API tokens yet (planned separately).
For now, issue one directly against the API:

**1. Log in to get a JWT** (the login endpoint is a standard OAuth2 password
form, not JSON — `username` here means your email):

```bash
curl -X POST https://your-server/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=you@example.com&password=yourpassword"
# => {"access_token": "...", "refresh_token": "...", "token_type": "bearer"}
```

**2. Create a personal API token**, authenticating with that JWT. The raw
token is only ever returned in this one response — store it now, the server
only keeps a hash of it:

```bash
curl -X POST https://your-server/api/v1/api-tokens \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"name": "my script"}'
# => {"id": "...", "name": "my script", "prefix": "dt_live_", "token": "dt_live_XXXXXXXX", ...}
```

**3. Use the token** for any endpoint, same as a JWT — full access to your
tasks, stats, and finance data:

```bash
curl https://your-server/api/v1/extra-tasks \
  -H "Authorization: Bearer dt_live_XXXXXXXX"
```

**List / revoke tokens:**

```bash
curl https://your-server/api/v1/api-tokens -H "Authorization: Bearer <access_token>"
curl -X DELETE https://your-server/api/v1/api-tokens/<token_id> -H "Authorization: Bearer <access_token>"
```

Revoking sets `revoked_at` — the token stops working immediately but the
record (and its usage history) isn't deleted.

## License

MIT — see [LICENSE](LICENSE).

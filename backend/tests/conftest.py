from collections.abc import AsyncGenerator
from urllib.parse import urlsplit

import asyncpg
import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import settings
from app.db.base import Base
from app.db.session import get_db
from app.main import app

TEST_DB_NAME = "deadline_tracker_test"
TEST_DATABASE_URL = settings.database_url.rsplit("/", 1)[0] + f"/{TEST_DB_NAME}"


@pytest.fixture(scope="session", autouse=True)
async def _ensure_test_database() -> None:
    # asyncpg (not the +asyncpg SQLAlchemy URL) needs a plain postgres:// DSN.
    parts = urlsplit(settings.database_url.replace("postgresql+asyncpg://", "postgresql://"))
    admin_conn = await asyncpg.connect(
        user=parts.username,
        password=parts.password,
        host=parts.hostname,
        port=parts.port,
        database="postgres",
    )
    try:
        exists = await admin_conn.fetchval(
            "SELECT 1 FROM pg_database WHERE datname = $1", TEST_DB_NAME
        )
        if not exists:
            await admin_conn.execute(f'CREATE DATABASE "{TEST_DB_NAME}"')
    finally:
        await admin_conn.close()


@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Fresh schema per test — simple and safe, at the cost of a bit of speed."""
    engine = create_async_engine(TEST_DATABASE_URL)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)

    session_factory = async_sessionmaker(bind=engine, expire_on_commit=False)
    session = session_factory()

    async def _override_get_db() -> AsyncGenerator[AsyncSession, None]:
        yield session

    app.dependency_overrides[get_db] = _override_get_db
    try:
        yield session
    finally:
        app.dependency_overrides.pop(get_db, None)
        await session.close()
        await engine.dispose()


@pytest.fixture
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

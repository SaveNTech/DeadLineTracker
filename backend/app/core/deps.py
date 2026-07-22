import uuid
from datetime import UTC, datetime

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import decode_token, hash_api_token
from app.db.session import get_db
from app.models.api_token import ApiToken
from app.models.user import User

bearer_scheme = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if credentials is None:
        raise unauthorized

    token = credentials.credentials

    if token.startswith(settings.api_token_prefix):
        user = await _authenticate_api_token(token, db)
        if user is None:
            raise unauthorized
        return user

    try:
        payload = decode_token(token)
    except jwt.PyJWTError as exc:
        raise unauthorized from exc

    if payload.get("type") != "access":
        raise unauthorized

    try:
        user_id = uuid.UUID(payload["sub"])
    except (KeyError, ValueError) as exc:
        raise unauthorized from exc

    user = await db.get(User, user_id)
    if user is None or not user.is_active:
        raise unauthorized
    return user


async def _authenticate_api_token(token: str, db: AsyncSession) -> User | None:
    token_hash = hash_api_token(token)
    result = await db.execute(select(ApiToken).where(ApiToken.token_hash == token_hash))
    api_token = result.scalar_one_or_none()

    if api_token is None or api_token.revoked_at is not None:
        return None

    api_token.last_used_at = datetime.now(UTC)
    await db.commit()

    user = await db.get(User, api_token.user_id)
    if user is None or not user.is_active:
        return None
    return user

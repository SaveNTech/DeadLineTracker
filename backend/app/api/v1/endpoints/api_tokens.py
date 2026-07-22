import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.security import generate_api_token
from app.db.session import get_db
from app.models.api_token import ApiToken
from app.models.user import User
from app.schemas.api_token import ApiTokenCreate, ApiTokenCreated, ApiTokenRead

router = APIRouter(prefix="/api-tokens", tags=["api-tokens"])


@router.get("", response_model=list[ApiTokenRead])
async def list_tokens(
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
) -> list[ApiTokenRead]:
    result = await db.execute(select(ApiToken).where(ApiToken.user_id == user.id))
    return [ApiTokenRead.model_validate(t) for t in result.scalars().all()]


@router.post("", response_model=ApiTokenCreated, status_code=status.HTTP_201_CREATED)
async def create_token(
    data: ApiTokenCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ApiTokenCreated:
    raw_token, prefix, token_hash = generate_api_token()
    token = ApiToken(
        user_id=user.id,
        name=data.name,
        token_hash=token_hash,
        prefix=prefix,
        scopes=data.scopes,
    )
    db.add(token)
    await db.commit()
    await db.refresh(token)
    # the raw token is only ever shown to the caller here; only its hash is stored
    return ApiTokenCreated(**ApiTokenRead.model_validate(token).model_dump(), token=raw_token)


@router.delete("/{token_id}", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_token(
    token_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    token = await db.get(ApiToken, token_id)
    if token is None or token.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Token not found")
    token.revoked_at = datetime.now(UTC)
    await db.commit()

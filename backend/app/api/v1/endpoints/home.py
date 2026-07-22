from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.home import HomeSummary
from app.services import home_service

router = APIRouter(prefix="/home", tags=["home"])


@router.get("/summary", response_model=HomeSummary)
async def summary(
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
) -> HomeSummary:
    return await home_service.get_home_summary(db, user)

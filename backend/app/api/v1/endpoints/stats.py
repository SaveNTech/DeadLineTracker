from datetime import date as date_type
from datetime import timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.stats import DailyStatPoint, StatsSummary
from app.services import stats_service

router = APIRouter(prefix="/stats", tags=["stats"])


@router.get("/daily", response_model=list[DailyStatPoint])
async def daily_stats(
    date_from: date_type = Query(
        default_factory=lambda: date_type.today() - timedelta(days=29), alias="from"
    ),
    date_to: date_type = Query(default_factory=date_type.today, alias="to"),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[DailyStatPoint]:
    return await stats_service.get_daily_stats(db, user, date_from, date_to)


@router.get("/summary", response_model=StatsSummary)
async def summary(
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
) -> StatsSummary:
    return await stats_service.get_stats_summary(db, user)

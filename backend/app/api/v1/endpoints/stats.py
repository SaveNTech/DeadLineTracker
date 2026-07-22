import csv
import io
import uuid
from datetime import date as date_type
from datetime import timedelta

from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.stats import DailyStatPoint, StatsSummary, TaskLogResponse, TemplateStatsDetail
from app.services import stats_service

router = APIRouter(prefix="/stats", tags=["stats"])


def _default_from() -> date_type:
    return date_type.today() - timedelta(days=29)


@router.get("/daily", response_model=list[DailyStatPoint])
async def daily_stats(
    date_from: date_type = Query(default_factory=_default_from, alias="from"),
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


@router.get("/log", response_model=TaskLogResponse)
async def task_log(
    date_from: date_type = Query(default_factory=_default_from, alias="from"),
    date_to: date_type = Query(default_factory=date_type.today, alias="to"),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TaskLogResponse:
    return await stats_service.get_task_log(db, user, date_from, date_to)


@router.get("/log/export")
async def export_task_log_csv(
    date_from: date_type = Query(default_factory=_default_from, alias="from"),
    date_to: date_type = Query(default_factory=date_type.today, alias="to"),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> StreamingResponse:
    log = await stats_service.get_task_log(db, user, date_from, date_to)

    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(["date", "kind", "title", "deadline", "completed", "overdue"])
    for entry in log.entries:
        writer.writerow(
            [
                entry.date.isoformat(),
                entry.kind,
                entry.title,
                entry.deadline.isoformat() if entry.deadline else "",
                entry.is_completed,
                entry.is_overdue,
            ]
        )
    buffer.seek(0)

    filename = f"deadlinetracker_{date_from.isoformat()}_{date_to.isoformat()}.csv"
    return StreamingResponse(
        iter([buffer.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/daily-tasks/{template_id}", response_model=TemplateStatsDetail)
async def daily_task_history(
    template_id: uuid.UUID,
    date_from: date_type = Query(
        default_factory=lambda: date_type.today() - timedelta(days=89), alias="from"
    ),
    date_to: date_type = Query(default_factory=date_type.today, alias="to"),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TemplateStatsDetail:
    return await stats_service.get_template_history(db, user, template_id, date_from, date_to)

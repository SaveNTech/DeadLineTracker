import uuid
from datetime import UTC, datetime, timedelta
from datetime import date as date_type

from fastapi import HTTPException, status
from sqlalchemy import cast, func, select
from sqlalchemy.dialects.postgresql import DATE
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.daily_task import DailyTaskInstance, DailyTaskTemplate
from app.models.extra_task import ExtraTask
from app.models.user import User
from app.schemas.stats import (
    DailyStatPoint,
    StatsSummary,
    TaskLogEntry,
    TaskLogResponse,
    TemplateHistoryPoint,
    TemplateStatsDetail,
)


def _compute_streaks(day_completion: list[tuple[date_type, bool]]) -> tuple[int, int]:
    """day_completion must be sorted by date descending. Returns (current, longest)."""
    current_streak = 0
    today = date_type.today()
    expected_date = today
    for d, completed in day_completion:
        if d == expected_date and completed:
            current_streak += 1
            expected_date -= timedelta(days=1)
        elif d == today and not completed:
            break
        elif d < expected_date:
            break

    longest_streak = 0
    running = 0
    for _d, completed in reversed(day_completion):
        if completed:
            running += 1
            longest_streak = max(longest_streak, running)
        else:
            running = 0

    return current_streak, longest_streak


async def get_daily_stats(
    db: AsyncSession, user: User, date_from: date_type, date_to: date_type
) -> list[DailyStatPoint]:
    daily_rows = await db.execute(
        select(
            DailyTaskInstance.date,
            func.count(DailyTaskInstance.id),
            func.count(DailyTaskInstance.id).filter(DailyTaskInstance.is_completed.is_(True)),
        )
        .where(
            DailyTaskInstance.user_id == user.id,
            DailyTaskInstance.date >= date_from,
            DailyTaskInstance.date <= date_to,
        )
        .group_by(DailyTaskInstance.date)
    )
    daily_by_date = {row[0]: (row[1], row[2]) for row in daily_rows.all()}

    created_date = cast(ExtraTask.created_at, DATE)
    extra_created_rows = await db.execute(
        select(created_date, func.count(ExtraTask.id))
        .where(ExtraTask.user_id == user.id, created_date >= date_from, created_date <= date_to)
        .group_by(created_date)
    )
    extra_total_by_date = dict(extra_created_rows.all())

    completed_date = cast(ExtraTask.completed_at, DATE)
    extra_completed_rows = await db.execute(
        select(completed_date, func.count(ExtraTask.id))
        .where(
            ExtraTask.user_id == user.id,
            ExtraTask.completed_at.is_not(None),
            completed_date >= date_from,
            completed_date <= date_to,
        )
        .group_by(completed_date)
    )
    extra_completed_by_date = dict(extra_completed_rows.all())

    points: list[DailyStatPoint] = []
    current = date_from
    while current <= date_to:
        daily_total, daily_completed = daily_by_date.get(current, (0, 0))
        points.append(
            DailyStatPoint(
                date=current,
                daily_total=daily_total,
                daily_completed=daily_completed,
                extra_total=extra_total_by_date.get(current, 0),
                extra_completed=extra_completed_by_date.get(current, 0),
            )
        )
        current += timedelta(days=1)
    return points


async def get_stats_summary(db: AsyncSession, user: User) -> StatsSummary:
    rows = await db.execute(
        select(
            DailyTaskInstance.date,
            func.count(DailyTaskInstance.id),
            func.count(DailyTaskInstance.id).filter(DailyTaskInstance.is_completed.is_(True)),
        )
        .where(DailyTaskInstance.user_id == user.id)
        .group_by(DailyTaskInstance.date)
        .order_by(DailyTaskInstance.date.desc())
    )
    by_date_desc = rows.all()

    def is_perfect_day(total: int, completed: int) -> bool:
        return total > 0 and total == completed

    current_streak, longest_streak = _compute_streaks(
        [(d, is_perfect_day(total, completed)) for d, total, completed in by_date_desc]
    )

    total_daily_completed = await db.scalar(
        select(func.count(DailyTaskInstance.id)).where(
            DailyTaskInstance.user_id == user.id, DailyTaskInstance.is_completed.is_(True)
        )
    )
    total_extra_completed = await db.scalar(
        select(func.count(ExtraTask.id)).where(
            ExtraTask.user_id == user.id, ExtraTask.is_completed.is_(True)
        )
    )

    return StatsSummary(
        current_streak=current_streak,
        longest_streak=longest_streak,
        total_tasks_completed=(total_daily_completed or 0) + (total_extra_completed or 0),
        days_tracked=len(by_date_desc),
    )


async def get_task_log(
    db: AsyncSession, user: User, date_from: date_type, date_to: date_type
) -> TaskLogResponse:
    daily_rows = await db.execute(
        select(DailyTaskInstance, DailyTaskTemplate.title, DailyTaskTemplate.due_time)
        .join(DailyTaskTemplate, DailyTaskInstance.template_id == DailyTaskTemplate.id)
        .where(
            DailyTaskInstance.user_id == user.id,
            DailyTaskInstance.date >= date_from,
            DailyTaskInstance.date <= date_to,
        )
    )

    entries: list[TaskLogEntry] = []
    for instance, title, due_time in daily_rows.all():
        deadline = (
            datetime.combine(instance.date, due_time, tzinfo=UTC) if due_time is not None else None
        )
        is_overdue = (
            deadline is not None and not instance.is_completed and deadline < datetime.now(UTC)
        )
        entries.append(
            TaskLogEntry(
                kind="daily",
                id=instance.id,
                title=title,
                date=instance.date,
                deadline=deadline,
                is_completed=instance.is_completed,
                is_overdue=is_overdue,
            )
        )

    extra_rows = await db.execute(
        select(ExtraTask).where(ExtraTask.user_id == user.id)
    )
    now = datetime.now(UTC)
    for task in extra_rows.scalars().all():
        anchor_date = (task.deadline or task.created_at).date()
        if not (date_from <= anchor_date <= date_to):
            continue
        is_overdue = (
            task.deadline is not None and not task.is_completed and task.deadline < now
        )
        entries.append(
            TaskLogEntry(
                kind="extra",
                id=task.id,
                title=task.title,
                date=anchor_date,
                deadline=task.deadline,
                is_completed=task.is_completed,
                is_overdue=is_overdue,
            )
        )

    entries.sort(key=lambda e: e.date, reverse=True)
    completed = sum(1 for e in entries if e.is_completed)
    return TaskLogResponse(
        total=len(entries),
        completed=completed,
        not_completed=len(entries) - completed,
        entries=entries,
    )


async def get_template_history(
    db: AsyncSession,
    user: User,
    template_id: uuid.UUID,
    date_from: date_type,
    date_to: date_type,
) -> TemplateStatsDetail:
    template = await db.get(DailyTaskTemplate, template_id)
    if template is None or template.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Daily task not found")

    rows = await db.execute(
        select(DailyTaskInstance.date, DailyTaskInstance.is_completed)
        .where(
            DailyTaskInstance.template_id == template_id,
            DailyTaskInstance.date >= date_from,
            DailyTaskInstance.date <= date_to,
        )
        .order_by(DailyTaskInstance.date.desc())
    )
    rows_desc = rows.all()
    current_streak, longest_streak = _compute_streaks(list(rows_desc))

    return TemplateStatsDetail(
        template_id=template_id,
        title=template.title,
        total_days=len(rows_desc),
        completed_days=sum(1 for _d, completed in rows_desc if completed),
        current_streak=current_streak,
        longest_streak=longest_streak,
        history=[
            TemplateHistoryPoint(date=d, is_completed=completed)
            for d, completed in reversed(rows_desc)
        ],
    )

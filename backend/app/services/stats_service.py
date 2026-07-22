from datetime import date as date_type
from datetime import timedelta

from sqlalchemy import cast, func, select
from sqlalchemy.dialects.postgresql import DATE
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.daily_task import DailyTaskInstance
from app.models.extra_task import ExtraTask
from app.models.user import User
from app.schemas.stats import DailyStatPoint, StatsSummary


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

    current_streak = 0
    today = date_type.today()
    expected_date = today
    for d, total, completed in by_date_desc:
        if d == expected_date and is_perfect_day(total, completed):
            current_streak += 1
            expected_date -= timedelta(days=1)
        elif d == today and not is_perfect_day(total, completed):
            break
        elif d < expected_date:
            break

    longest_streak = 0
    running = 0
    for _d, total, completed in reversed(by_date_desc):
        if is_perfect_day(total, completed):
            running += 1
            longest_streak = max(longest_streak, running)
        else:
            running = 0

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

from datetime import UTC, datetime, timedelta
from datetime import date as date_type

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.extra_task import PRIORITY_HIGH, ExtraTask
from app.models.user import User
from app.schemas.home import HomeSummary, HomeTaskRef
from app.services import task_service


def _minutes_remaining(deadline: datetime | None) -> int | None:
    if deadline is None:
        return None
    return int((deadline - datetime.now(UTC)).total_seconds() // 60)


def _extra_task_overdue(task: ExtraTask) -> bool:
    return task.deadline is not None and not task.is_completed and task.deadline < datetime.now(UTC)


async def get_home_summary(db: AsyncSession, user: User) -> HomeSummary:
    today = date_type.today()
    now = datetime.now(UTC)

    daily_instances = await task_service.get_daily_instances_for_date(db, user, today)

    result = await db.execute(select(ExtraTask).where(ExtraTask.user_id == user.id))
    extra_tasks = list(result.scalars().all())

    # --- today ring: daily instances today + extra tasks due today-or-earlier
    # (still open) or completed today (so finishing an old overdue task still
    # counts toward "what I got done today").
    today_total = len(daily_instances)
    today_completed = sum(1 for i in daily_instances if i.is_completed)
    for t in extra_tasks:
        is_due_today_or_earlier = t.deadline is not None and t.deadline.date() <= today
        completed_today = (
            t.is_completed and t.completed_at is not None and t.completed_at.date() == today
        )
        if is_due_today_or_earlier or completed_today:
            today_total += 1
            if t.is_completed:
                today_completed += 1

    # --- urgent / next: every open item with a deadline, earliest first
    # (an overdue deadline sorts first automatically, matching "urgent").
    candidates: list[HomeTaskRef] = []
    for i in daily_instances:
        if i.is_completed or i.due_time is None:
            continue
        deadline = datetime.combine(i.date, i.due_time, tzinfo=UTC)
        candidates.append(
            HomeTaskRef(
                kind="daily",
                id=i.id,
                title=i.title,
                deadline=deadline,
                priority=None,
                is_overdue=i.is_overdue,
                minutes_remaining=_minutes_remaining(deadline),
            )
        )
    for t in extra_tasks:
        if t.is_completed or t.deadline is None:
            continue
        candidates.append(
            HomeTaskRef(
                kind="extra",
                id=t.id,
                title=t.title,
                deadline=t.deadline,
                priority=t.priority,
                is_overdue=_extra_task_overdue(t),
                minutes_remaining=_minutes_remaining(t.deadline),
            )
        )
    candidates.sort(key=lambda c: c.deadline)

    urgent = candidates[0] if candidates else None
    next_item = candidates[1] if len(candidates) > 1 else None

    if urgent is None:
        fallback = max(
            (t for t in extra_tasks if not t.is_completed),
            key=lambda t: (t.priority, t.created_at),
            default=None,
        )
        if fallback is not None:
            urgent = HomeTaskRef(
                kind="extra",
                id=fallback.id,
                title=fallback.title,
                deadline=None,
                priority=fallback.priority,
                is_overdue=False,
                minutes_remaining=None,
            )

    # --- week highlights: high-priority extra tasks due in the next 7 days
    week_end = now + timedelta(days=7)
    week_highlights = [
        HomeTaskRef(
            kind="extra",
            id=t.id,
            title=t.title,
            deadline=t.deadline,
            priority=t.priority,
            is_overdue=False,  # week_highlights only ever contains future deadlines
            minutes_remaining=_minutes_remaining(t.deadline),
        )
        for t in sorted(extra_tasks, key=lambda t: t.deadline or datetime.max.replace(tzinfo=UTC))
        if not t.is_completed
        and t.priority == PRIORITY_HIGH
        and t.deadline is not None
        and now <= t.deadline <= week_end
    ]

    return HomeSummary(
        today_total=today_total,
        today_completed=today_completed,
        urgent=urgent,
        next=next_item,
        week_highlights=week_highlights,
    )

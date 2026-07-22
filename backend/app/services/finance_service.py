import uuid
from datetime import UTC, datetime
from datetime import date as date_type
from decimal import Decimal

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.finance import SOURCE_DAILY_TASK, SOURCE_MANUAL, FinancialGoal, IncomeEntry
from app.models.user import User
from app.schemas.finance import (
    FinanceSummary,
    GoalCreate,
    GoalRead,
    GoalUpdate,
    IncomeEntryCreate,
    IncomeEntryUpdate,
)

ZERO = Decimal("0")


async def _get_owned_goal(db: AsyncSession, user: User, goal_id: uuid.UUID) -> FinancialGoal:
    goal = await db.get(FinancialGoal, goal_id)
    if goal is None or goal.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Goal not found")
    return goal


async def _goal_current_amount(db: AsyncSession, goal_id: uuid.UUID) -> Decimal:
    total = await db.scalar(
        select(func.coalesce(func.sum(IncomeEntry.amount), ZERO)).where(
            IncomeEntry.goal_id == goal_id
        )
    )
    return total or ZERO


async def _to_goal_read(db: AsyncSession, goal: FinancialGoal) -> GoalRead:
    current = await _goal_current_amount(db, goal.id)
    return GoalRead(
        id=goal.id,
        title=goal.title,
        target_amount=goal.target_amount,
        currency=goal.currency,
        achieved_at=goal.achieved_at,
        current_amount=current,
    )


async def _maybe_mark_achieved(db: AsyncSession, goal: FinancialGoal) -> None:
    if goal.achieved_at is not None:
        return
    current = await _goal_current_amount(db, goal.id)
    if current >= goal.target_amount:
        goal.achieved_at = datetime.now(UTC)
        await db.commit()


async def create_goal(db: AsyncSession, user: User, data: GoalCreate) -> GoalRead:
    goal = FinancialGoal(user_id=user.id, **data.model_dump())
    db.add(goal)
    await db.commit()
    await db.refresh(goal)
    return await _to_goal_read(db, goal)


async def list_goals(db: AsyncSession, user: User) -> list[GoalRead]:
    result = await db.execute(
        select(FinancialGoal)
        .where(FinancialGoal.user_id == user.id)
        .order_by(FinancialGoal.created_at)
    )
    return [await _to_goal_read(db, g) for g in result.scalars().all()]


async def update_goal(
    db: AsyncSession, user: User, goal_id: uuid.UUID, data: GoalUpdate
) -> GoalRead:
    goal = await _get_owned_goal(db, user, goal_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(goal, field, value)
    await db.commit()
    await db.refresh(goal)
    await _maybe_mark_achieved(db, goal)
    return await _to_goal_read(db, goal)


async def delete_goal(db: AsyncSession, user: User, goal_id: uuid.UUID) -> None:
    goal = await _get_owned_goal(db, user, goal_id)
    await db.delete(goal)
    await db.commit()


async def create_income_entry(
    db: AsyncSession,
    user: User,
    *,
    amount: Decimal,
    entry_date: date_type | None = None,
    note: str | None = None,
    goal_id: uuid.UUID | None = None,
    source: str = SOURCE_MANUAL,
    daily_task_instance_id: uuid.UUID | None = None,
) -> IncomeEntry:
    if goal_id is not None:
        await _get_owned_goal(db, user, goal_id)  # 404s if not owned

    entry = IncomeEntry(
        user_id=user.id,
        amount=amount,
        entry_date=entry_date or datetime.now(UTC).date(),
        note=note,
        goal_id=goal_id,
        source=source,
        daily_task_instance_id=daily_task_instance_id,
    )
    db.add(entry)
    await db.commit()
    await db.refresh(entry)

    if goal_id is not None:
        goal = await db.get(FinancialGoal, goal_id)
        if goal is not None:
            await _maybe_mark_achieved(db, goal)

    return entry


async def create_manual_income_entry(
    db: AsyncSession, user: User, data: IncomeEntryCreate
) -> IncomeEntry:
    return await create_income_entry(
        db,
        user,
        amount=data.amount,
        entry_date=data.entry_date,
        note=data.note,
        goal_id=data.goal_id,
        source=SOURCE_MANUAL,
    )


async def delete_income_entry_for_instance(
    db: AsyncSession, user: User, instance_id: uuid.UUID
) -> None:
    result = await db.execute(
        select(IncomeEntry).where(
            IncomeEntry.user_id == user.id,
            IncomeEntry.daily_task_instance_id == instance_id,
            IncomeEntry.source == SOURCE_DAILY_TASK,
        )
    )
    entry = result.scalar_one_or_none()
    if entry is not None:
        await db.delete(entry)
        await db.commit()


async def _get_owned_entry(db: AsyncSession, user: User, entry_id: uuid.UUID) -> IncomeEntry:
    entry = await db.get(IncomeEntry, entry_id)
    if entry is None or entry.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Income entry not found")
    return entry


async def list_income_entries(
    db: AsyncSession,
    user: User,
    date_from: date_type | None = None,
    date_to: date_type | None = None,
) -> list[IncomeEntry]:
    query = select(IncomeEntry).where(IncomeEntry.user_id == user.id)
    if date_from is not None:
        query = query.where(IncomeEntry.entry_date >= date_from)
    if date_to is not None:
        query = query.where(IncomeEntry.entry_date <= date_to)
    query = query.order_by(IncomeEntry.entry_date.desc(), IncomeEntry.created_at.desc())
    result = await db.execute(query)
    return list(result.scalars().all())


async def update_income_entry(
    db: AsyncSession, user: User, entry_id: uuid.UUID, data: IncomeEntryUpdate
) -> IncomeEntry:
    entry = await _get_owned_entry(db, user, entry_id)
    updates = data.model_dump(exclude_unset=True)
    if "goal_id" in updates and updates["goal_id"] is not None:
        await _get_owned_goal(db, user, updates["goal_id"])
    for field, value in updates.items():
        setattr(entry, field, value)
    await db.commit()
    await db.refresh(entry)
    if entry.goal_id is not None:
        goal = await db.get(FinancialGoal, entry.goal_id)
        if goal is not None:
            await _maybe_mark_achieved(db, goal)
    return entry


async def delete_income_entry(db: AsyncSession, user: User, entry_id: uuid.UUID) -> None:
    entry = await _get_owned_entry(db, user, entry_id)
    await db.delete(entry)
    await db.commit()


async def get_finance_summary(db: AsyncSession, user: User) -> FinanceSummary:
    total_all_time = await db.scalar(
        select(func.coalesce(func.sum(IncomeEntry.amount), ZERO)).where(
            IncomeEntry.user_id == user.id
        )
    )
    month_start = datetime.now(UTC).date().replace(day=1)
    total_this_month = await db.scalar(
        select(func.coalesce(func.sum(IncomeEntry.amount), ZERO)).where(
            IncomeEntry.user_id == user.id, IncomeEntry.entry_date >= month_start
        )
    )
    unallocated = await db.scalar(
        select(func.coalesce(func.sum(IncomeEntry.amount), ZERO)).where(
            IncomeEntry.user_id == user.id, IncomeEntry.goal_id.is_(None)
        )
    )
    return FinanceSummary(
        total_all_time=total_all_time or ZERO,
        total_this_month=total_this_month or ZERO,
        unallocated_amount=unallocated or ZERO,
    )

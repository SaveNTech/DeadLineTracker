import uuid
from datetime import UTC, datetime, time
from datetime import date as date_type
from decimal import Decimal

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.daily_task import DailyTaskInstance, DailyTaskTemplate
from app.models.extra_task import ExtraTask
from app.models.finance import SOURCE_DAILY_TASK
from app.models.user import User
from app.schemas.daily_task import (
    DailyTaskInstanceRead,
    DailyTaskTemplateCreate,
    DailyTaskTemplateUpdate,
)
from app.schemas.extra_task import ExtraTaskCreate, ExtraTaskUpdate
from app.services import finance_service


def _is_overdue(deadline: datetime | None, is_completed: bool) -> bool:
    if deadline is None or is_completed:
        return False
    return deadline < datetime.now(UTC)


def _sort_key(deadline: datetime | None, is_completed: bool, position: int) -> tuple:
    overdue = _is_overdue(deadline, is_completed)
    # bucket 0 = active, 1 = overdue, 2 = completed — matches required display order
    bucket = 2 if is_completed else (1 if overdue else 0)
    deadline_sort = deadline or datetime.max.replace(tzinfo=UTC)
    return (bucket, deadline_sort, position)


# --- Daily task templates -------------------------------------------------


async def _get_owned_template(
    db: AsyncSession, user: User, template_id: uuid.UUID
) -> DailyTaskTemplate:
    template = await db.get(DailyTaskTemplate, template_id)
    if template is None or template.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Daily task not found")
    return template


async def create_daily_template(
    db: AsyncSession, user: User, data: DailyTaskTemplateCreate
) -> DailyTaskTemplate:
    template = DailyTaskTemplate(user_id=user.id, **data.model_dump())
    db.add(template)
    await db.commit()
    await db.refresh(template)
    return template


async def list_daily_templates(db: AsyncSession, user: User) -> list[DailyTaskTemplate]:
    result = await db.execute(
        select(DailyTaskTemplate)
        .where(DailyTaskTemplate.user_id == user.id)
        .order_by(DailyTaskTemplate.position, DailyTaskTemplate.created_at)
    )
    return list(result.scalars().all())


async def update_daily_template(
    db: AsyncSession, user: User, template_id: uuid.UUID, data: DailyTaskTemplateUpdate
) -> DailyTaskTemplate:
    template = await _get_owned_template(db, user, template_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(template, field, value)
    await db.commit()
    await db.refresh(template)
    return template


async def delete_daily_template(db: AsyncSession, user: User, template_id: uuid.UUID) -> None:
    template = await _get_owned_template(db, user, template_id)
    await db.delete(template)
    await db.commit()


# --- Daily task instances (materialized per day) --------------------------


def _deadline_for(date: date_type, due_time: time | None) -> datetime | None:
    if due_time is None:
        return None
    return datetime.combine(date, due_time, tzinfo=UTC)


async def get_daily_instances_for_date(
    db: AsyncSession, user: User, date: date_type
) -> list[DailyTaskInstanceRead]:
    templates = await db.execute(
        select(DailyTaskTemplate).where(
            DailyTaskTemplate.user_id == user.id, DailyTaskTemplate.is_active.is_(True)
        )
    )
    templates = list(templates.scalars().all())

    existing = await db.execute(
        select(DailyTaskInstance).where(
            DailyTaskInstance.user_id == user.id, DailyTaskInstance.date == date
        )
    )
    existing_by_template = {i.template_id: i for i in existing.scalars().all()}

    created_any = False
    for template in templates:
        if template.id not in existing_by_template:
            instance = DailyTaskInstance(
                template_id=template.id, user_id=user.id, date=date, is_completed=False
            )
            db.add(instance)
            existing_by_template[template.id] = instance
            created_any = True
    if created_any:
        await db.commit()
        for instance in existing_by_template.values():
            await db.refresh(instance)

    template_by_id = {t.id: t for t in templates}

    items: list[DailyTaskInstanceRead] = []
    for instance in existing_by_template.values():
        template = template_by_id.get(instance.template_id)
        if template is None:
            continue  # template deactivated/deleted after this instance was created
        deadline = _deadline_for(date, template.due_time)
        items.append(
            DailyTaskInstanceRead(
                id=instance.id,
                template_id=instance.template_id,
                title=template.title,
                description=template.description,
                date=instance.date,
                due_time=template.due_time,
                is_financial=template.is_financial,
                is_completed=instance.is_completed,
                completed_at=instance.completed_at,
                is_overdue=_is_overdue(deadline, instance.is_completed),
            )
        )

    items.sort(
        key=lambda i: _sort_key(
            _deadline_for(i.date, i.due_time),
            i.is_completed,
            template_by_id[i.template_id].position,
        )
    )
    return items


async def _get_owned_instance(
    db: AsyncSession, user: User, instance_id: uuid.UUID
) -> DailyTaskInstance:
    instance = await db.get(DailyTaskInstance, instance_id)
    if instance is None or instance.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Daily task not found")
    return instance


async def complete_daily_instance(
    db: AsyncSession,
    user: User,
    instance_id: uuid.UUID,
    amount: Decimal | None,
    goal_id: uuid.UUID | None,
) -> DailyTaskInstance:
    instance = await _get_owned_instance(db, user, instance_id)
    template = await db.get(DailyTaskTemplate, instance.template_id)

    if template is not None and template.is_financial and amount is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="This is a financial task — amount is required to complete it",
        )

    instance.is_completed = True
    instance.completed_at = datetime.now(UTC)
    await db.commit()
    await db.refresh(instance)

    if template is not None and template.is_financial and amount is not None:
        await finance_service.create_income_entry(
            db,
            user,
            amount=amount,
            entry_date=instance.date,
            goal_id=goal_id,
            source=SOURCE_DAILY_TASK,
            daily_task_instance_id=instance.id,
            note=template.title,
        )

    return instance


async def uncomplete_daily_instance(
    db: AsyncSession, user: User, instance_id: uuid.UUID
) -> DailyTaskInstance:
    instance = await _get_owned_instance(db, user, instance_id)
    instance.is_completed = False
    instance.completed_at = None
    await db.commit()
    await db.refresh(instance)
    await finance_service.delete_income_entry_for_instance(db, user, instance_id)
    return instance


# --- Extra (one-off) tasks --------------------------------------------------


async def _get_owned_extra_task(db: AsyncSession, user: User, task_id: uuid.UUID) -> ExtraTask:
    task = await db.get(ExtraTask, task_id)
    if task is None or task.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found")
    return task


def _with_overdue(task: ExtraTask) -> ExtraTask:
    task.is_overdue = _is_overdue(task.deadline, task.is_completed)  # type: ignore[attr-defined]
    return task


async def create_extra_task(db: AsyncSession, user: User, data: ExtraTaskCreate) -> ExtraTask:
    task = ExtraTask(user_id=user.id, **data.model_dump())
    db.add(task)
    await db.commit()
    await db.refresh(task)
    return _with_overdue(task)


async def list_extra_tasks(db: AsyncSession, user: User) -> list[ExtraTask]:
    result = await db.execute(select(ExtraTask).where(ExtraTask.user_id == user.id))
    tasks = [_with_overdue(t) for t in result.scalars().all()]
    tasks.sort(key=lambda t: _sort_key(t.deadline, t.is_completed, t.position))
    return tasks


async def update_extra_task(
    db: AsyncSession, user: User, task_id: uuid.UUID, data: ExtraTaskUpdate
) -> ExtraTask:
    task = await _get_owned_extra_task(db, user, task_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(task, field, value)
    await db.commit()
    await db.refresh(task)
    return _with_overdue(task)


async def delete_extra_task(db: AsyncSession, user: User, task_id: uuid.UUID) -> None:
    task = await _get_owned_extra_task(db, user, task_id)
    await db.delete(task)
    await db.commit()


async def set_extra_task_completed(
    db: AsyncSession, user: User, task_id: uuid.UUID, completed: bool
) -> ExtraTask:
    task = await _get_owned_extra_task(db, user, task_id)
    task.is_completed = completed
    task.completed_at = datetime.now(UTC) if completed else None
    await db.commit()
    await db.refresh(task)
    return _with_overdue(task)

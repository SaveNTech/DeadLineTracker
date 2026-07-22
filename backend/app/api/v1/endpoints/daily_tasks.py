import uuid
from datetime import date as date_type

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.daily_task import (
    DailyTaskCompleteRequest,
    DailyTaskInstanceRead,
    DailyTaskTemplateCreate,
    DailyTaskTemplateRead,
    DailyTaskTemplateUpdate,
)
from app.services import task_service

router = APIRouter(prefix="/daily-tasks", tags=["daily-tasks"])


@router.get("/templates", response_model=list[DailyTaskTemplateRead])
async def list_templates(
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
) -> list[DailyTaskTemplateRead]:
    templates = await task_service.list_daily_templates(db, user)
    return [DailyTaskTemplateRead.model_validate(t) for t in templates]


@router.post(
    "/templates", response_model=DailyTaskTemplateRead, status_code=status.HTTP_201_CREATED
)
async def create_template(
    data: DailyTaskTemplateCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> DailyTaskTemplateRead:
    template = await task_service.create_daily_template(db, user, data)
    return DailyTaskTemplateRead.model_validate(template)


@router.patch("/templates/{template_id}", response_model=DailyTaskTemplateRead)
async def update_template(
    template_id: uuid.UUID,
    data: DailyTaskTemplateUpdate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> DailyTaskTemplateRead:
    template = await task_service.update_daily_template(db, user, template_id, data)
    return DailyTaskTemplateRead.model_validate(template)


@router.delete("/templates/{template_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_template(
    template_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    await task_service.delete_daily_template(db, user, template_id)


@router.get("", response_model=list[DailyTaskInstanceRead])
async def list_today_instances(
    for_date: date_type = Query(default_factory=date_type.today, alias="date"),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[DailyTaskInstanceRead]:
    return await task_service.get_daily_instances_for_date(db, user, for_date)


async def _read_instance(
    db: AsyncSession, user: User, instance_id: uuid.UUID, date: date_type
) -> DailyTaskInstanceRead:
    for item in await task_service.get_daily_instances_for_date(db, user, date):
        if item.id == instance_id:
            return item
    raise LookupError(f"Instance {instance_id} vanished after update")


@router.patch("/{instance_id}/complete", response_model=DailyTaskInstanceRead)
async def complete_instance(
    instance_id: uuid.UUID,
    data: DailyTaskCompleteRequest | None = None,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> DailyTaskInstanceRead:
    body = data or DailyTaskCompleteRequest()
    instance = await task_service.complete_daily_instance(
        db, user, instance_id, body.amount, body.goal_id
    )
    return await _read_instance(db, user, instance_id, instance.date)


@router.patch("/{instance_id}/uncomplete", response_model=DailyTaskInstanceRead)
async def uncomplete_instance(
    instance_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> DailyTaskInstanceRead:
    instance = await task_service.uncomplete_daily_instance(db, user, instance_id)
    return await _read_instance(db, user, instance_id, instance.date)

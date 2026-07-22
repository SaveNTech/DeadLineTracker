import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.extra_task import ExtraTaskCreate, ExtraTaskRead, ExtraTaskUpdate
from app.services import task_service

router = APIRouter(prefix="/extra-tasks", tags=["extra-tasks"])


@router.get("", response_model=list[ExtraTaskRead])
async def list_tasks(
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
) -> list[ExtraTaskRead]:
    tasks = await task_service.list_extra_tasks(db, user)
    return [ExtraTaskRead.model_validate(t) for t in tasks]


@router.post("", response_model=ExtraTaskRead, status_code=status.HTTP_201_CREATED)
async def create_task(
    data: ExtraTaskCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ExtraTaskRead:
    task = await task_service.create_extra_task(db, user, data)
    return ExtraTaskRead.model_validate(task)


@router.patch("/{task_id}", response_model=ExtraTaskRead)
async def update_task(
    task_id: uuid.UUID,
    data: ExtraTaskUpdate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ExtraTaskRead:
    task = await task_service.update_extra_task(db, user, task_id, data)
    return ExtraTaskRead.model_validate(task)


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_task(
    task_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    await task_service.delete_extra_task(db, user, task_id)


@router.patch("/{task_id}/complete", response_model=ExtraTaskRead)
async def complete_task(
    task_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ExtraTaskRead:
    task = await task_service.set_extra_task_completed(db, user, task_id, True)
    return ExtraTaskRead.model_validate(task)


@router.patch("/{task_id}/uncomplete", response_model=ExtraTaskRead)
async def uncomplete_task(
    task_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ExtraTaskRead:
    task = await task_service.set_extra_task_completed(db, user, task_id, False)
    return ExtraTaskRead.model_validate(task)

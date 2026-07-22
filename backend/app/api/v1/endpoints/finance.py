import uuid
from datetime import date as date_type

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.finance import (
    FinanceSummary,
    GoalCreate,
    GoalRead,
    GoalUpdate,
    IncomeEntryCreate,
    IncomeEntryRead,
    IncomeEntryUpdate,
)
from app.services import finance_service

router = APIRouter(prefix="/finance", tags=["finance"])


@router.get("/summary", response_model=FinanceSummary)
async def summary(
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
) -> FinanceSummary:
    return await finance_service.get_finance_summary(db, user)


@router.get("/goals", response_model=list[GoalRead])
async def list_goals(
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
) -> list[GoalRead]:
    return await finance_service.list_goals(db, user)


@router.post("/goals", response_model=GoalRead, status_code=status.HTTP_201_CREATED)
async def create_goal(
    data: GoalCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> GoalRead:
    return await finance_service.create_goal(db, user, data)


@router.patch("/goals/{goal_id}", response_model=GoalRead)
async def update_goal(
    goal_id: uuid.UUID,
    data: GoalUpdate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> GoalRead:
    return await finance_service.update_goal(db, user, goal_id, data)


@router.delete("/goals/{goal_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_goal(
    goal_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    await finance_service.delete_goal(db, user, goal_id)


@router.get("/income", response_model=list[IncomeEntryRead])
async def list_income(
    date_from: date_type | None = Query(default=None, alias="from"),
    date_to: date_type | None = Query(default=None, alias="to"),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[IncomeEntryRead]:
    entries = await finance_service.list_income_entries(db, user, date_from, date_to)
    return [IncomeEntryRead.model_validate(e) for e in entries]


@router.post("/income", response_model=IncomeEntryRead, status_code=status.HTTP_201_CREATED)
async def create_income(
    data: IncomeEntryCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> IncomeEntryRead:
    entry = await finance_service.create_manual_income_entry(db, user, data)
    return IncomeEntryRead.model_validate(entry)


@router.patch("/income/{entry_id}", response_model=IncomeEntryRead)
async def update_income(
    entry_id: uuid.UUID,
    data: IncomeEntryUpdate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> IncomeEntryRead:
    entry = await finance_service.update_income_entry(db, user, entry_id, data)
    return IncomeEntryRead.model_validate(entry)


@router.delete("/income/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_income(
    entry_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    await finance_service.delete_income_entry(db, user, entry_id)

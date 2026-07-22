import uuid
from datetime import date as date_type
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, computed_field


class GoalCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    target_amount: Decimal = Field(gt=0)
    currency: str = Field(default="RUB", min_length=3, max_length=3)


class GoalUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    target_amount: Decimal | None = Field(default=None, gt=0)


class GoalRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    title: str
    target_amount: Decimal
    currency: str
    achieved_at: datetime | None
    current_amount: Decimal

    @computed_field
    @property
    def progress(self) -> float:
        if self.target_amount <= 0:
            return 0.0
        return min(float(self.current_amount / self.target_amount), 1.0)


class IncomeEntryCreate(BaseModel):
    amount: Decimal = Field(gt=0)
    entry_date: date_type | None = None
    note: str | None = Field(default=None, max_length=280)
    goal_id: uuid.UUID | None = None


class IncomeEntryUpdate(BaseModel):
    goal_id: uuid.UUID | None = None
    note: str | None = Field(default=None, max_length=280)


class IncomeEntryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    amount: Decimal
    currency: str
    source: str
    entry_date: date_type
    note: str | None
    daily_task_instance_id: uuid.UUID | None
    goal_id: uuid.UUID | None
    created_at: datetime


class FinanceSummary(BaseModel):
    total_all_time: Decimal
    total_this_month: Decimal
    unallocated_amount: Decimal

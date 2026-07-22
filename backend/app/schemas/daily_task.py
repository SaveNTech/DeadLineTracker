import uuid
from datetime import date as date_type
from datetime import datetime, time
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class DailyTaskTemplateCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    due_time: time | None = None
    is_financial: bool = False


class DailyTaskTemplateUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    due_time: time | None = None
    is_active: bool | None = None
    is_financial: bool | None = None
    position: int | None = None


class DailyTaskTemplateRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    title: str
    description: str | None
    due_time: time | None
    is_active: bool
    is_financial: bool
    position: int


class DailyTaskInstanceRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    template_id: uuid.UUID
    title: str
    description: str | None
    date: date_type
    due_time: time | None
    is_financial: bool
    is_completed: bool
    completed_at: datetime | None
    is_overdue: bool


class DailyTaskCompleteRequest(BaseModel):
    """Body for PATCH /daily-tasks/{id}/complete.

    `amount` is required when the instance's template is financial and
    ignored otherwise; `goal_id` optionally allocates the resulting income
    entry to a goal right away.
    """

    amount: Decimal | None = Field(default=None, gt=0)
    goal_id: uuid.UUID | None = None

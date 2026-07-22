import uuid
from datetime import date as date_type
from datetime import datetime, time

from pydantic import BaseModel, ConfigDict, Field


class DailyTaskTemplateCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    due_time: time | None = None


class DailyTaskTemplateUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    due_time: time | None = None
    is_active: bool | None = None
    position: int | None = None


class DailyTaskTemplateRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    title: str
    description: str | None
    due_time: time | None
    is_active: bool
    position: int


class DailyTaskInstanceRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    template_id: uuid.UUID
    title: str
    description: str | None
    date: date_type
    due_time: time | None
    is_completed: bool
    completed_at: datetime | None
    is_overdue: bool

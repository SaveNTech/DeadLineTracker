import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ExtraTaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    deadline: datetime | None = None


class ExtraTaskUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    deadline: datetime | None = None
    position: int | None = None


class ExtraTaskRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    title: str
    description: str | None
    deadline: datetime | None
    is_completed: bool
    completed_at: datetime | None
    position: int
    is_overdue: bool

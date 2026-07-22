import uuid
from datetime import date as date_type
from datetime import datetime

from pydantic import BaseModel, computed_field


class DailyStatPoint(BaseModel):
    date: date_type
    daily_total: int
    daily_completed: int
    extra_total: int
    extra_completed: int

    @computed_field
    @property
    def total(self) -> int:
        return self.daily_total + self.extra_total

    @computed_field
    @property
    def completed(self) -> int:
        return self.daily_completed + self.extra_completed


class StatsSummary(BaseModel):
    current_streak: int
    longest_streak: int
    total_tasks_completed: int
    days_tracked: int


class TaskLogEntry(BaseModel):
    """One row in the Statistics tab's period list (daily instance or extra task)."""

    kind: str  # "daily" | "extra"
    id: uuid.UUID
    title: str
    date: date_type
    deadline: datetime | None
    is_completed: bool
    is_overdue: bool


class TaskLogResponse(BaseModel):
    total: int
    completed: int
    not_completed: int

    @computed_field
    @property
    def completion_rate(self) -> float:
        return 0.0 if self.total == 0 else self.completed / self.total

    entries: list[TaskLogEntry]


class TemplateHistoryPoint(BaseModel):
    date: date_type
    is_completed: bool


class TemplateStatsDetail(BaseModel):
    template_id: uuid.UUID
    title: str
    total_days: int
    completed_days: int
    current_streak: int
    longest_streak: int
    history: list[TemplateHistoryPoint]

    @computed_field
    @property
    def completion_rate(self) -> float:
        return 0.0 if self.total_days == 0 else self.completed_days / self.total_days

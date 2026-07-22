from datetime import date as date_type

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

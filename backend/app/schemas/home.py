import uuid
from datetime import datetime

from pydantic import BaseModel


class HomeTaskRef(BaseModel):
    kind: str  # "daily" | "extra"
    id: uuid.UUID
    title: str
    deadline: datetime | None
    priority: int | None  # only meaningful for kind == "extra"
    is_overdue: bool
    minutes_remaining: int | None  # negative if overdue, null if no deadline


class HomeSummary(BaseModel):
    today_total: int
    today_completed: int
    urgent: HomeTaskRef | None
    next: HomeTaskRef | None
    week_highlights: list[HomeTaskRef]

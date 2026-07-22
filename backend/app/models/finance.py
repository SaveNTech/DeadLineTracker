import uuid
from datetime import date as date_type
from datetime import datetime
from decimal import Decimal

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Numeric, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, new_uuid

SOURCE_DAILY_TASK = "daily_task"
SOURCE_MANUAL = "manual"


class FinancialGoal(Base, TimestampMixin):
    """Something the user is saving toward (e.g. paying off a loan)."""

    __tablename__ = "financial_goals"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    target_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(3), default="RUB", nullable=False)
    achieved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class IncomeEntry(Base, TimestampMixin):
    """A logged amount of money earned — either auto-created when a
    'financial' daily task instance is completed, or added manually.
    Optionally allocated to a FinancialGoal."""

    __tablename__ = "income_entries"
    __table_args__ = (
        CheckConstraint("source IN ('daily_task', 'manual')", name="ck_income_entry_source"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(3), default="RUB", nullable=False)
    source: Mapped[str] = mapped_column(String(20), default=SOURCE_MANUAL, nullable=False)
    entry_date: Mapped[date_type] = mapped_column(Date, nullable=False, index=True)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    daily_task_instance_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("daily_task_instances.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    goal_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("financial_goals.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

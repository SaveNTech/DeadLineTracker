from datetime import UTC, datetime, timedelta

from httpx import AsyncClient


async def _register_and_login(client: AsyncClient) -> dict[str, str]:
    await client.post(
        "/api/v1/auth/register",
        json={"email": "bob@example.com", "username": "bob", "password": "supersecret"},
    )
    login = await client.post(
        "/api/v1/auth/login",
        data={"username": "bob@example.com", "password": "supersecret"},
    )
    assert login.status_code == 200, login.text
    token = login.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


async def test_extra_task_priority_defaults_and_is_settable(client: AsyncClient) -> None:
    headers = await _register_and_login(client)

    default_task = await client.post(
        "/api/v1/extra-tasks", json={"title": "Something"}, headers=headers
    )
    assert default_task.status_code == 201
    assert default_task.json()["priority"] == 1

    high_task = await client.post(
        "/api/v1/extra-tasks",
        json={"title": "Important", "priority": 3},
        headers=headers,
    )
    assert high_task.status_code == 201
    assert high_task.json()["priority"] == 3


async def test_financial_daily_task_requires_amount_to_complete(client: AsyncClient) -> None:
    headers = await _register_and_login(client)

    template = await client.post(
        "/api/v1/daily-tasks/templates",
        json={"title": "Earn something", "is_financial": True},
        headers=headers,
    )
    assert template.status_code == 201

    today = await client.get("/api/v1/daily-tasks", headers=headers)
    instance_id = today.json()[0]["id"]
    assert today.json()[0]["is_financial"] is True

    missing_amount = await client.patch(
        f"/api/v1/daily-tasks/{instance_id}/complete", headers=headers
    )
    assert missing_amount.status_code == 422

    with_amount = await client.patch(
        f"/api/v1/daily-tasks/{instance_id}/complete",
        json={"amount": "150.50"},
        headers=headers,
    )
    assert with_amount.status_code == 200
    assert with_amount.json()["is_completed"] is True

    income = await client.get("/api/v1/finance/income", headers=headers)
    assert income.status_code == 200
    assert len(income.json()) == 1
    assert income.json()[0]["amount"] == "150.50"
    assert income.json()[0]["source"] == "daily_task"

    # uncompleting should remove the auto-created income entry
    uncomplete = await client.patch(
        f"/api/v1/daily-tasks/{instance_id}/uncomplete", headers=headers
    )
    assert uncomplete.status_code == 200
    income_after = await client.get("/api/v1/finance/income", headers=headers)
    assert income_after.json() == []


async def test_goal_progress_from_linked_income(client: AsyncClient) -> None:
    headers = await _register_and_login(client)

    goal = await client.post(
        "/api/v1/finance/goals",
        json={"title": "Pay off loan", "target_amount": "1000.00"},
        headers=headers,
    )
    assert goal.status_code == 201
    goal_id = goal.json()["id"]
    assert goal.json()["progress"] == 0.0

    await client.post(
        "/api/v1/finance/income",
        json={"amount": "400.00", "goal_id": goal_id},
        headers=headers,
    )
    await client.post(
        "/api/v1/finance/income",
        json={"amount": "600.00", "goal_id": goal_id},
        headers=headers,
    )

    goals = await client.get("/api/v1/finance/goals", headers=headers)
    updated = goals.json()[0]
    assert updated["current_amount"] == "1000.00"
    assert updated["progress"] == 1.0
    assert updated["achieved_at"] is not None


async def test_home_summary_surfaces_urgent_and_week_highlights(client: AsyncClient) -> None:
    headers = await _register_and_login(client)

    soon = (datetime.now(UTC) + timedelta(hours=1)).isoformat()
    later = (datetime.now(UTC) + timedelta(days=3)).isoformat()

    await client.post(
        "/api/v1/extra-tasks",
        json={"title": "Due soon", "deadline": soon, "priority": 2},
        headers=headers,
    )
    await client.post(
        "/api/v1/extra-tasks",
        json={"title": "Important this week", "deadline": later, "priority": 3},
        headers=headers,
    )

    home = await client.get("/api/v1/home/summary", headers=headers)
    assert home.status_code == 200
    body = home.json()
    assert body["urgent"]["title"] == "Due soon"
    assert body["urgent"]["minutes_remaining"] is not None
    assert len(body["week_highlights"]) == 1
    assert body["week_highlights"][0]["title"] == "Important this week"


async def test_stats_log_and_csv_export(client: AsyncClient) -> None:
    headers = await _register_and_login(client)
    await client.post("/api/v1/extra-tasks", json={"title": "Log me"}, headers=headers)

    log = await client.get("/api/v1/stats/log", headers=headers)
    assert log.status_code == 200
    assert log.json()["total"] == 1

    export = await client.get("/api/v1/stats/log/export", headers=headers)
    assert export.status_code == 200
    assert export.headers["content-type"].startswith("text/csv")
    assert "Log me" in export.text

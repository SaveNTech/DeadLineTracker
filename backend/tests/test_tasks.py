from datetime import UTC, datetime, timedelta

from httpx import AsyncClient


async def _register_and_login(client: AsyncClient) -> dict[str, str]:
    await client.post(
        "/api/v1/auth/register",
        json={"email": "alice@example.com", "username": "alice", "password": "supersecret"},
    )
    login = await client.post(
        "/api/v1/auth/login",
        data={"username": "alice@example.com", "password": "supersecret"},
    )
    assert login.status_code == 200, login.text
    token = login.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


async def test_register_and_login(client: AsyncClient) -> None:
    headers = await _register_and_login(client)
    me = await client.get("/api/v1/users/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["email"] == "alice@example.com"


async def test_daily_task_template_generates_todays_instance_and_completes(
    client: AsyncClient,
) -> None:
    headers = await _register_and_login(client)

    create = await client.post(
        "/api/v1/daily-tasks/templates",
        json={"title": "Meditate", "description": "10 minutes"},
        headers=headers,
    )
    assert create.status_code == 201, create.text

    today = await client.get("/api/v1/daily-tasks", headers=headers)
    assert today.status_code == 200
    instances = today.json()
    assert len(instances) == 1
    assert instances[0]["title"] == "Meditate"
    assert instances[0]["is_completed"] is False

    instance_id = instances[0]["id"]
    completed = await client.patch(
        f"/api/v1/daily-tasks/{instance_id}/complete", headers=headers
    )
    assert completed.status_code == 200
    assert completed.json()["is_completed"] is True

    summary = await client.get("/api/v1/stats/summary", headers=headers)
    assert summary.status_code == 200
    assert summary.json()["total_tasks_completed"] == 1


async def test_extra_task_overdue_then_completable(client: AsyncClient) -> None:
    headers = await _register_and_login(client)

    past_deadline = (datetime.now(UTC) - timedelta(hours=1)).isoformat()
    create = await client.post(
        "/api/v1/extra-tasks",
        json={"title": "Pay rent", "deadline": past_deadline},
        headers=headers,
    )
    assert create.status_code == 201, create.text
    task = create.json()
    assert task["is_overdue"] is True
    assert task["is_completed"] is False

    complete = await client.patch(
        f"/api/v1/extra-tasks/{task['id']}/complete", headers=headers
    )
    assert complete.status_code == 200
    body = complete.json()
    assert body["is_completed"] is True
    assert body["is_overdue"] is False  # completed tasks are never shown as overdue


async def test_api_token_authenticates_like_a_session(client: AsyncClient) -> None:
    headers = await _register_and_login(client)

    created = await client.post(
        "/api/v1/api-tokens", json={"name": "integration"}, headers=headers
    )
    assert created.status_code == 201, created.text
    raw_token = created.json()["token"]
    assert raw_token.startswith("dt_live_")

    me = await client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {raw_token}"})
    assert me.status_code == 200
    assert me.json()["username"] == "alice"

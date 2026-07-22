from fastapi import APIRouter

from app.api.v1.endpoints import api_tokens, auth, daily_tasks, extra_tasks, stats, users

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(daily_tasks.router)
api_router.include_router(extra_tasks.router)
api_router.include_router(stats.router)
api_router.include_router(api_tokens.router)

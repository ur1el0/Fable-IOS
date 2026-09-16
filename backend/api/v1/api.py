from fastapi import APIRouter
from api.v1.endpoints import health, stories, shelf, gutenberg

api_router = APIRouter()

api_router.include_router(health.router, tags=["health"])
api_router.include_router(stories.router, tags=["stories"])
api_router.include_router(shelf.router, tags=["shelf"])
api_router.include_router(gutenberg.router, tags=["gutenberg"])

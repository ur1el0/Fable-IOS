from fastapi import APIRouter, Header, Request, status
from schemas import (
    RegisterRequest,
    LoginRequest,
    ProfileUpdateRequest,
    AuthResponse,
    StoryDTO,
    UserDTO,
    ReadingSessionRequest,
    ReadingStatsDTO,
)
from services import auth_service, story_service, reading_stats
from services.auth_rate_limit import enforce_auth_rate_limit

router = APIRouter()

@router.post("/auth/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
def register(req: RegisterRequest, request: Request):
    client_host = request.client.host if request.client else "unknown"
    enforce_auth_rate_limit("register", client_host)
    return auth_service.register_user(req)

@router.post("/auth/login", response_model=AuthResponse)
def login(req: LoginRequest, request: Request):
    client_host = request.client.host if request.client else "unknown"
    enforce_auth_rate_limit("login", client_host, req.email)
    return auth_service.login_user(req)

@router.get("/auth/me", response_model=UserDTO)
def get_me(authorization: str = Header(None)):
    return auth_service.get_current_user_from_header(authorization)


@router.get("/auth/me/stories", response_model=list[StoryDTO])
def get_my_stories(authorization: str = Header(None)):
    user = auth_service.get_current_user_from_header(authorization)
    return story_service.get_user_stories(user.id)



@router.patch("/auth/me", response_model=UserDTO)
def update_me(req: ProfileUpdateRequest, authorization: str = Header(None)):
    auth_service.get_current_user_from_header(authorization)
    token = authorization.split(" ", 1)[1]
    return auth_service.update_current_user(token, req)


@router.post("/auth/me/reading-sessions", status_code=status.HTTP_204_NO_CONTENT)
def record_reading_session(
    request: ReadingSessionRequest,
    authorization: str = Header(None),
):
    user = auth_service.get_current_user_from_header(authorization)
    reading_stats.record_reading_session(user.id, request)


@router.get("/auth/me/stats", response_model=ReadingStatsDTO)
def get_reading_stats(authorization: str = Header(None)):
    user = auth_service.get_current_user_from_header(authorization)
    return reading_stats.get_reading_stats(user.id)


@router.post("/auth/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(authorization: str = Header(None)):
    auth_service.get_current_user_from_header(authorization)
    token = authorization.split(" ", 1)[1].strip()
    auth_service.revoke_session(token)

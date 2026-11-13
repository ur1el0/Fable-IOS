from fastapi import APIRouter, BackgroundTasks, Header, HTTPException, Request, Response, status
from core.rate_limit import extract_client_ip
from schemas import (
    RegisterRequest,
    LoginRequest,
    ProfileUpdateRequest,
    AuthResponse,
    StoryDTO,
    UserDTO,
    ReadingSessionRequest,
    ReadingStatsDTO,
    PasswordResetRequest,
    PasswordResetConfirmRequest,
)
from services import auth_service, story_service, reading_stats
from services.auth_rate_limit import enforce_auth_rate_limit
from services.password_reset_email import (
    EmailDeliveryConfigurationError,
    deliver_password_reset_email,
    load_smtp_settings,
)

router = APIRouter()

@router.post("/auth/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
def register(req: RegisterRequest, request: Request):
    client_host = extract_client_ip(request)
    enforce_auth_rate_limit("register", client_host)
    return auth_service.register_user(req)

@router.post("/auth/login", response_model=AuthResponse)
def login(req: LoginRequest, request: Request):
    client_host = extract_client_ip(request)
    enforce_auth_rate_limit("login", client_host, req.email)
    return auth_service.login_user(req)


@router.post("/auth/password-reset/request", status_code=status.HTTP_202_ACCEPTED)
def request_password_reset(
    payload: PasswordResetRequest,
    request: Request,
    background_tasks: BackgroundTasks,
):
    try:
        smtp_settings = load_smtp_settings()
    except EmailDeliveryConfigurationError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Password recovery is temporarily unavailable.",
        ) from error

    client_host = extract_client_ip(request)
    enforce_auth_rate_limit("password_reset", client_host, payload.email)
    token = auth_service.issue_password_reset_token(payload.email)
    if token is not None:
        background_tasks.add_task(
            deliver_password_reset_email,
            smtp_settings,
            payload.email,
            token,
        )
    return {
        "message": "If an account uses this address, recovery instructions will arrive shortly."
    }


@router.post("/auth/password-reset/confirm", status_code=status.HTTP_204_NO_CONTENT)
def confirm_password_reset(payload: PasswordResetConfirmRequest, request: Request):
    client_host = extract_client_ip(request)
    enforce_auth_rate_limit("password_reset_confirm", client_host, payload.token[:16])
    auth_service.reset_password_with_token(payload.token, payload.new_password)
    return Response(status_code=status.HTTP_204_NO_CONTENT)

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
    token = authorization.split(" ", 1)[1].strip()
    return auth_service.update_current_user(token, req)


@router.delete("/auth/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_me(authorization: str = Header(None)):
    auth_service.get_current_user_from_header(authorization)
    token = authorization.split(" ", 1)[1].strip()
    auth_service.delete_current_user(token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


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

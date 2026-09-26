from fastapi import APIRouter, Header, status
from schemas import RegisterRequest, LoginRequest, ProfileUpdateRequest, AuthResponse, StoryDTO, UserDTO
from services import auth_service, story_service

router = APIRouter()

@router.post("/auth/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
def register(req: RegisterRequest):
    return auth_service.register_user(req)

@router.post("/auth/login", response_model=AuthResponse)
def login(req: LoginRequest):
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

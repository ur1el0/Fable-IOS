from fastapi import APIRouter, Header, HTTPException, status
from schemas import RegisterRequest, LoginRequest, AuthResponse, UserDTO
from services import auth_service

router = APIRouter()

@router.post("/auth/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
def register(req: RegisterRequest):
    return auth_service.register_user(req)

@router.post("/auth/login", response_model=AuthResponse)
def login(req: LoginRequest):
    return auth_service.login_user(req)

@router.get("/auth/me", response_model=UserDTO)
def get_me(authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header. Expected 'Bearer <token>'"
        )
    token = authorization.split(" ", 1)[1]
    return auth_service.get_current_user(token)

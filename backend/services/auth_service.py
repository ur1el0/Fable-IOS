import hashlib
import hmac
import secrets
from datetime import datetime, timezone
from uuid import UUID, uuid4
from typing import Optional
from fastapi import HTTPException, status
from core.database import get_db
from schemas.schemas import UserDTO, RegisterRequest, LoginRequest, AuthResponse, ProfileUpdateRequest

# In-memory session store mapping active bearer token -> user_id
ACTIVE_SESSIONS: dict[str, str] = {}


def _avatar_image_name(row) -> Optional[str]:
    value = row["avatar_image_name"]
    return None if value == "avatar_roosc" else value



def _to_user_dto(row) -> UserDTO:
    return UserDTO(
        id=UUID(row["id"]),
        email=row["email"],
        name=row["name"],
        handle=row["handle"],
        bio=row["bio"],
        avatar_image_name=_avatar_image_name(row),
        avatar_image_url=row["avatar_image_url"],
        created_at_utc=datetime.fromisoformat(row["created_at_utc"])
    )


def _normalized_handle(value: str) -> str:
    handle = value.strip()
    if not handle:
        return ""
    return handle if handle.startswith("@") else f"@{handle}"

def hash_password(password: str) -> str:
    """Hash password using PBKDF2-HMAC-SHA256 with 100,000 iterations and 16-byte random salt."""
    salt = secrets.token_hex(16)
    key = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), 100000)
    return f"{salt}${key.hex()}"

def verify_password(stored_hash: str, password: str) -> bool:
    """Verify password against stored salt$hash using constant-time comparison."""
    try:
        salt, key = stored_hash.split("$", 1)
        calculated = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), 100000)
        return hmac.compare_digest(key, calculated.hex())
    except (ValueError, AttributeError):
        return False

def register_user(req: RegisterRequest) -> AuthResponse:
    """Register a new user account with validated credentials and return authentication token."""
    normalized_email = req.email.strip().lower()
    conn = get_db()
    try:
        with conn:
            existing = conn.execute("SELECT id FROM users WHERE email = ?", (normalized_email,)).fetchone()
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Email is already registered"
                )

            user_id = str(uuid4())
            now = datetime.now(timezone.utc).isoformat()
            pwd_hash = hash_password(req.password)
            conn.execute("""
                INSERT INTO users (id, email, password_hash, name, handle, bio, avatar_image_name, created_at_utc, updated_at_utc)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (user_id, normalized_email, pwd_hash, req.name.strip(), _normalized_handle(req.handle), "", None, now, now))
    finally:
        conn.close()

    token = secrets.token_urlsafe(32)
    ACTIVE_SESSIONS[token] = user_id
    conn = get_db()
    try:
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    finally:
        conn.close()
    user_dto = _to_user_dto(row)
    return AuthResponse(access_token=token, token_type="bearer", user=user_dto)

def login_user(req: LoginRequest) -> AuthResponse:
    """Authenticate user with email and password, issuing a bearer session token."""
    normalized_email = req.email.strip().lower()
    conn = get_db()
    row = conn.execute("SELECT * FROM users WHERE email = ?", (normalized_email,)).fetchone()
    conn.close()

    if not row or not verify_password(row["password_hash"], req.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )

    token = secrets.token_urlsafe(32)
    ACTIVE_SESSIONS[token] = row["id"]
    user_dto = _to_user_dto(row)
    return AuthResponse(access_token=token, token_type="bearer", user=user_dto)

def get_current_user(token: str) -> UserDTO:
    """Retrieve user entity associated with an active bearer token."""
    user_id = ACTIVE_SESSIONS.get(token)
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired session token"
        )

    conn = get_db()
    row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    conn.close()

    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    return _to_user_dto(row)


def get_current_user_from_header(authorization: Optional[str]) -> UserDTO:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header. Expected 'Bearer <token>'",
        )
    return get_current_user(authorization.split(" ", 1)[1])


def update_current_user(token: str, req: ProfileUpdateRequest) -> UserDTO:
    user_id = ACTIVE_SESSIONS.get(token)
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired session token"
        )

    now = datetime.now(timezone.utc).isoformat()
    conn = get_db()
    try:
        with conn:
            result = conn.execute(
                """UPDATE users SET name = ?, handle = ?, bio = ?, updated_at_utc = ? WHERE id = ?""",
                (req.name.strip(), _normalized_handle(req.handle), req.bio.strip(), now, user_id)
            )
            if result.rowcount != 1:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
            row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    finally:
        conn.close()

    return _to_user_dto(row)

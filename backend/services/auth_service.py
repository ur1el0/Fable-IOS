import hashlib
import hmac
import secrets
from datetime import datetime, timezone
from uuid import UUID, uuid4
from fastapi import HTTPException, status
from core.database import get_db
from schemas.schemas import UserDTO, RegisterRequest, LoginRequest, AuthResponse

# In-memory session store mapping active bearer token -> user_id
ACTIVE_SESSIONS: dict[str, str] = {}

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
                INSERT INTO users (id, email, password_hash, name, avatar_image_name, created_at_utc, updated_at_utc)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (user_id, normalized_email, pwd_hash, req.name.strip(), "avatar_roosc", now, now))
    finally:
        conn.close()

    token = secrets.token_urlsafe(32)
    ACTIVE_SESSIONS[token] = user_id
    user_dto = UserDTO(
        id=UUID(user_id),
        email=normalized_email,
        name=req.name.strip(),
        avatar_image_name="avatar_roosc",
        created_at_utc=datetime.fromisoformat(now)
    )
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
    user_dto = UserDTO(
        id=UUID(row["id"]),
        email=row["email"],
        name=row["name"],
        avatar_image_name=row["avatar_image_name"] or "avatar_roosc",
        avatar_image_url=row["avatar_image_url"],
        created_at_utc=datetime.fromisoformat(row["created_at_utc"])
    )
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

    return UserDTO(
        id=UUID(row["id"]),
        email=row["email"],
        name=row["name"],
        avatar_image_name=row["avatar_image_name"] or "avatar_roosc",
        avatar_image_url=row["avatar_image_url"],
        created_at_utc=datetime.fromisoformat(row["created_at_utc"])
    )

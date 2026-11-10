from __future__ import annotations

import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4
from typing import Optional, Tuple
from fastapi import HTTPException, status
from core.database import get_db
from schemas.schemas import UserDTO, RegisterRequest, LoginRequest, AuthResponse, ProfileUpdateRequest

SESSION_LIFETIME = timedelta(days=30)
PASSWORD_RESET_TOKEN_LIFETIME = timedelta(minutes=15)
PASSWORD_HASH_ITERATIONS = 600_000
LEGACY_PASSWORD_HASH_ITERATIONS = 100_000
MAX_PASSWORD_HASH_ITERATIONS = 10_000_000
PASSWORD_HASH_ALGORITHM = "pbkdf2_sha256"
DUMMY_PASSWORD_HASH = (
    f"{PASSWORD_HASH_ALGORITHM}${PASSWORD_HASH_ITERATIONS}$"
    f"{'00' * 16}${'00' * hashlib.sha256().digest_size}"
)


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
    """Hash passwords with a versioned PBKDF2-HMAC-SHA256 format."""
    salt = secrets.token_bytes(16)
    key = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, PASSWORD_HASH_ITERATIONS)
    return f"{PASSWORD_HASH_ALGORITHM}${PASSWORD_HASH_ITERATIONS}${salt.hex()}${key.hex()}"


def _password_hash_parameters(stored_hash: str) -> Optional[Tuple[bytes, bytes, int]]:
    try:
        parts = stored_hash.split("$")
        if len(parts) == 2:
            salt_hex, digest_hex = parts
            salt = salt_hex.encode("utf-8")
            digest = bytes.fromhex(digest_hex)
            iterations = LEGACY_PASSWORD_HASH_ITERATIONS
        elif len(parts) == 4 and parts[0] == PASSWORD_HASH_ALGORITHM:
            iterations = int(parts[1])
            if not 1 <= iterations <= MAX_PASSWORD_HASH_ITERATIONS:
                return None
            salt = bytes.fromhex(parts[2])
            digest = bytes.fromhex(parts[3])
            if not 16 <= len(salt) <= 64:
                return None
        else:
            return None

        if len(digest) != hashlib.sha256().digest_size:
            return None
        return salt, digest, iterations
    except (ValueError, AttributeError, TypeError):
        return None

def verify_password(stored_hash: str, password: str) -> bool:
    """Verify a versioned hash or the legacy salt$hash format."""
    parameters = _password_hash_parameters(stored_hash)
    if parameters is None:
        return False
    salt, digest, iterations = parameters
    calculated = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
    return hmac.compare_digest(digest, calculated)


def password_needs_rehash(stored_hash: str) -> bool:
    """Return whether a verified credential should be upgraded to current parameters."""
    parts = stored_hash.split("$")
    if len(parts) != 4 or parts[0] != PASSWORD_HASH_ALGORITHM:
        return True
    parameters = _password_hash_parameters(stored_hash)
    return parameters is None or parameters[2] < PASSWORD_HASH_ITERATIONS

def _token_digest(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _issue_session(user_id: str) -> str:
    token = secrets.token_urlsafe(32)
    now = datetime.now(timezone.utc)
    conn = get_db()
    try:
        with conn:
            conn.execute(
                "DELETE FROM user_sessions WHERE expires_at_utc <= ? OR revoked_at_utc < ?",
                (now.isoformat(), (now - timedelta(days=30)).isoformat()),
            )
            conn.execute(
                """INSERT INTO user_sessions
                   (token_hash, user_id, created_at_utc, expires_at_utc, revoked_at_utc)
                   VALUES (?, ?, ?, ?, NULL)""",
                (
                    _token_digest(token),
                    user_id,
                    now.isoformat(),
                    (now + SESSION_LIFETIME).isoformat(),
                ),
            )
    finally:
        conn.close()
    return token


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

    token = _issue_session(user_id)
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
    try:
        row = conn.execute("SELECT * FROM users WHERE email = ?", (normalized_email,)).fetchone()
        if not row:
            verify_password(DUMMY_PASSWORD_HASH, req.password)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
        if not verify_password(row["password_hash"], req.password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )

        if password_needs_rehash(row["password_hash"]):
            replacement_hash = hash_password(req.password)
            with conn:
                updated = conn.execute(
                    "UPDATE users SET password_hash = ? WHERE id = ? AND password_hash = ?",
                    (replacement_hash, row["id"], row["password_hash"]),
                ).rowcount
            if updated != 1:
                current = conn.execute(
                    "SELECT password_hash FROM users WHERE id = ?", (row["id"],)
                ).fetchone()
                if not current or not verify_password(current["password_hash"], req.password):
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Invalid email or password"
                    )
    finally:
        conn.close()

    token = _issue_session(row["id"])
    user_dto = _to_user_dto(row)
    return AuthResponse(access_token=token, token_type="bearer", user=user_dto)

def get_current_user(token: str) -> UserDTO:
    """Retrieve a user through a persisted, expiring bearer-session digest."""
    now = datetime.now(timezone.utc).isoformat()
    conn = get_db()
    try:
        row = conn.execute(
            """SELECT users.* FROM user_sessions
               JOIN users ON users.id = user_sessions.user_id
               WHERE user_sessions.token_hash = ?
                 AND user_sessions.revoked_at_utc IS NULL
                 AND user_sessions.expires_at_utc > ?""",
            (_token_digest(token), now),
        ).fetchone()
    finally:
        conn.close()

    if not row:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired session token"
        )
    return _to_user_dto(row)


def get_current_user_from_header(authorization: Optional[str]) -> UserDTO:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header. Expected 'Bearer <token>'",
        )
    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid session token")
    return get_current_user(token)


def revoke_session(token: str) -> None:
    now = datetime.now(timezone.utc).isoformat()
    conn = get_db()
    try:
        with conn:
            conn.execute(
                "UPDATE user_sessions SET revoked_at_utc = ? WHERE token_hash = ? AND revoked_at_utc IS NULL",
                (now, _token_digest(token)),
            )
    finally:
        conn.close()


def update_current_user(token: str, req: ProfileUpdateRequest) -> UserDTO:
    user_id = str(get_current_user(token).id)

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


def issue_password_reset_token(email: str) -> Optional[str]:
    normalized_email = email.strip().lower()
    conn = get_db()
    try:
        user = conn.execute("SELECT id FROM users WHERE email = ?", (normalized_email,)).fetchone()
        if user is None:
            return None

        token = secrets.token_urlsafe(32)
        now = datetime.now(timezone.utc)
        with conn:
            conn.execute(
                "DELETE FROM password_reset_tokens WHERE expires_at_utc <= ? OR user_id = ?",
                (now.isoformat(), user["id"]),
            )
            conn.execute(
                """INSERT INTO password_reset_tokens
                   (token_hash, user_id, created_at_utc, expires_at_utc, consumed_at_utc)
                   VALUES (?, ?, ?, ?, NULL)""",
                (
                    _token_digest(token),
                    user["id"],
                    now.isoformat(),
                    (now + PASSWORD_RESET_TOKEN_LIFETIME).isoformat(),
                ),
            )
        return token
    finally:
        conn.close()


def discard_password_reset_token(token: str) -> None:
    conn = get_db()
    try:
        with conn:
            conn.execute(
                "DELETE FROM password_reset_tokens WHERE token_hash = ?",
                (_token_digest(token),),
            )
    finally:
        conn.close()


def reset_password_with_token(token: str, new_password: str) -> None:
    token_hash = _token_digest(token)
    now = datetime.now(timezone.utc)
    conn = get_db()
    try:
        conn.execute("BEGIN IMMEDIATE")
        reset = conn.execute(
            """SELECT user_id FROM password_reset_tokens
               WHERE token_hash = ? AND consumed_at_utc IS NULL AND expires_at_utc > ?""",
            (token_hash, now.isoformat()),
        ).fetchone()
        if reset is None:
            conn.rollback()
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired password reset code.",
            )

        password_hash = hash_password(new_password)
        changed = conn.execute(
            "UPDATE users SET password_hash = ?, updated_at_utc = ? WHERE id = ?",
            (password_hash, now.isoformat(), reset["user_id"]),
        ).rowcount
        consumed = conn.execute(
            """UPDATE password_reset_tokens SET consumed_at_utc = ?
               WHERE token_hash = ? AND consumed_at_utc IS NULL AND expires_at_utc > ?""",
            (now.isoformat(), token_hash, now.isoformat()),
        ).rowcount
        if changed != 1 or consumed != 1:
            conn.rollback()
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired password reset code.",
            )

        conn.execute(
            """UPDATE user_sessions SET revoked_at_utc = ?
               WHERE user_id = ? AND revoked_at_utc IS NULL""",
            (now.isoformat(), reset["user_id"]),
        )
        conn.execute(
            "DELETE FROM password_reset_tokens WHERE user_id = ? AND token_hash != ?",
            (reset["user_id"], token_hash),
        )
        conn.commit()
    except Exception:
        if conn.in_transaction:
            conn.rollback()
        raise
    finally:
        conn.close()

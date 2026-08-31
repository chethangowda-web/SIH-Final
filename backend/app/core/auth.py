import os
import hmac
import hashlib
import base64
import json
import time
import secrets
import sqlite3
from typing import List, Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from app.core.config import settings
from app.core.database import get_db
from app.core.logging_config import get_logger

logger = get_logger("auth_guard")

# Reuse standard OAuth2 password bearer flow
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login", auto_error=False)

def is_auth_mock_enabled() -> bool:
    """
    Check if test auth bypass is active.
    Strictly disabled if running in production mode or if ALLOW_TEST_AUTH_MOCK is False.
    """
    if settings.is_production or not settings.ALLOW_TEST_AUTH_MOCK:
        return False
    return os.getenv("PDS_TEST_AUTH_MOCK") == "1"

def hash_password(password: str, salt: Optional[str] = None) -> str:
    """Hash password securely using SHA-256 and a random salt."""
    if salt is None:
        salt = secrets.token_hex(16)
    hashed = hashlib.sha256((password + salt).encode()).hexdigest()
    return f"{salt}:{hashed}"

def verify_password(password: str, hashed_with_salt: str) -> bool:
    """Verify password matches hashed representation."""
    try:
        if ":" not in hashed_with_salt:
            return False
        salt, hashed = hashed_with_salt.split(":", 1)
        expected = hashlib.sha256((password + salt).encode()).hexdigest()
        return hmac.compare_digest(hashed, expected)
    except Exception:
        return False

def create_token(data: dict, expires_in: int = 36000) -> str:
    """Generate JWT-like signed token using HMAC-SHA256."""
    payload = {
        "sub": data,
        "exp": int(time.time()) + expires_in
    }
    payload_json = json.dumps(payload, separators=(',', ':'))
    payload_b64 = base64.urlsafe_b64encode(payload_json.encode()).decode().rstrip("=")
    signature = hmac.new(settings.SECRET_KEY.encode(), payload_b64.encode(), hashlib.sha256).hexdigest()
    return f"{payload_b64}.{signature}"

def verify_token(token: str) -> Optional[dict]:
    """Decode and verify token validity."""
    try:
        if "." not in token:
            return None
        payload_b64, signature = token.split(".", 1)
        
        # Verify signature with constant-time comparison
        expected_sig = hmac.new(settings.SECRET_KEY.encode(), payload_b64.encode(), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(signature, expected_sig):
            return None
            
        # Add padding back to base64 if needed
        padding = 4 - (len(payload_b64) % 4)
        if padding < 4:
            payload_b64 += "=" * padding
            
        payload_json = base64.urlsafe_b64decode(payload_b64.encode()).decode()
        payload = json.loads(payload_json)
        
        # Check expiration
        if payload["exp"] < time.time():
            return None
            
        return payload["sub"]
    except Exception:
        return None

def get_current_user(
    token: Optional[str] = Depends(oauth2_scheme),
    db: sqlite3.Connection = Depends(get_db)
) -> dict:
    """Dependency to retrieve and validate authenticated user identity."""
    if is_auth_mock_enabled() and not token:
        return {
            "id": 1,
            "username": "admin_user",
            "role": "ADMIN",
            "beneficiary_id": "BEN-KA-0001"
        }
        
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if not token:
        logger.warning("Authentication failed: missing Bearer token in request")
        raise credentials_exception
        
    user_payload = verify_token(token)
    if not user_payload or "username" not in user_payload:
        logger.warning("Authentication failed: invalid or expired Bearer token")
        raise credentials_exception
        
    username = user_payload["username"]
    cursor = db.cursor()
    cursor.execute(
        "SELECT id, username, role, beneficiary_id FROM users WHERE username = ?;",
        (username,)
    )
    user_row = cursor.fetchone()
    if not user_row:
        logger.warning("Authentication failed: user '%s' in token no longer exists", username)
        raise credentials_exception
        
    return {
        "id": user_row["id"],
        "username": user_row["username"],
        "role": user_row["role"],
        "beneficiary_id": user_row["beneficiary_id"]
    }

class RoleChecker:
    """Dependency validator to verify user role constraints."""
    def __init__(self, allowed_roles: List[str]):
        self.allowed_roles = allowed_roles

    def __call__(self, current_user: dict = Depends(get_current_user)) -> dict:
        if current_user["role"] not in self.allowed_roles:
            logger.warning(
                "Access Forbidden: user '%s' (role '%s') attempted access requiring %s",
                current_user.get("username"),
                current_user.get("role"),
                self.allowed_roles
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Operation not permitted. Required role: {self.allowed_roles}. Current: {current_user['role']}."
            )
        return current_user

from fastapi import Request

def check_admin_access(request: Request, current_user: dict = Depends(get_current_user)):
    """Enforce central administrative/operational role access matrix."""
    if is_auth_mock_enabled() and current_user.get("role") == "ADMIN":
        return current_user
        
    method = request.method
    path = request.url.path
    
    # 1. System reset is restricted to ADMIN only and subject to production lock
    if "/admin/demo/reset" in path:
        if settings.is_production and not settings.ALLOW_DEMO_RESET:
            logger.warning("Access Forbidden: system reset is blocked in production mode")
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="System reset endpoint is disabled in production environment."
            )
        if current_user["role"] != "ADMIN":
            logger.warning("Access Forbidden: user '%s' attempted reset without ADMIN role", current_user.get("username"))
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="System reset is restricted to ADMIN role."
            )
            
    # 2. Mutation requests (POST, PUT, DELETE) require DSO or ADMIN
    elif method in ["POST", "PUT", "DELETE"]:
        if current_user["role"] not in ["DSO", "ADMIN"]:
            logger.warning("Access Forbidden: user '%s' attempted %s %s without DSO/ADMIN role", current_user.get("username"), method, path)
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Mutation actions are restricted to DSO or ADMIN roles. Current: {current_user['role']}."
            )
            
    # 3. Read requests (GET) require DSO, ADMIN, or AUDITOR
    else:
        if current_user["role"] not in ["DSO", "ADMIN", "AUDITOR"]:
            logger.warning("Access Forbidden: user '%s' attempted GET %s without DSO/ADMIN/AUDITOR role", current_user.get("username"), path)
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access restricted to DSO, ADMIN, or AUDITOR roles. Current: {current_user['role']}."
            )
    return current_user

def verify_owner(current_user: dict, target_beneficiary_id: str):
    """Enforce owner-validation: BENEFICIARY role is restricted to own data."""
    if is_auth_mock_enabled():
        return
        
    if current_user["role"] == "BENEFICIARY":
        if not current_user["beneficiary_id"] or current_user["beneficiary_id"].strip() != target_beneficiary_id.strip():
            logger.warning(
                "Access Forbidden: beneficiary '%s' attempted accessing data of '%s'",
                current_user.get("username"),
                target_beneficiary_id
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access Denied: BENEFICIARY role is restricted to own data. Attempted access to {target_beneficiary_id}."
            )


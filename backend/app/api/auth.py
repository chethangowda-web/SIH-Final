import sqlite3
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel, Field
from typing import Optional

from app.core.database import get_db
from app.core.logging_config import get_logger
from app.core.auth import (
    hash_password,
    verify_password,
    create_token,
    get_current_user,
    RoleChecker
)

logger = get_logger("auth")

router = APIRouter(tags=["Authentication"])

class UserLoginOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    username: str
    beneficiary_id: Optional[str] = None

class UserRegisterIn(BaseModel):
    username: str = Field(..., min_length=3, max_length=64)
    password: str = Field(..., min_length=6, max_length=128)
    role: str = Field(..., max_length=32)
    beneficiary_id: Optional[str] = Field(None, max_length=64)

class UserOut(BaseModel):
    id: int
    username: str
    role: str
    beneficiary_id: Optional[str] = None

class LoginPayload(BaseModel):
    username: str = Field(..., max_length=64)
    password: str = Field(..., max_length=128)

@router.post("/auth/login", response_model=UserLoginOut)
def login(
    payload: LoginPayload,
    db: sqlite3.Connection = Depends(get_db)
):
    """Authenticate credentials and return standard Bearer access token."""
    cursor = db.cursor()
    cursor.execute(
        "SELECT id, username, password_hash, role, beneficiary_id FROM users WHERE username = ?;",
        (payload.username.strip(),)
    )
    user_row = cursor.fetchone()
    if not user_row or not verify_password(payload.password, user_row["password_hash"]):
        logger.warning(
            "Authentication failed for username='%s': invalid credentials or user not found",
            payload.username.strip()
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token_data = {
        "username": user_row["username"],
        "role": user_row["role"]
    }
    token = create_token(token_data)

    logger.info(
        "Authentication successful for username='%s', role='%s', beneficiary_id='%s'",
        user_row["username"],
        user_row["role"],
        user_row["beneficiary_id"]
    )
    
    return UserLoginOut(
        access_token=token,
        role=user_row["role"],
        username=user_row["username"],
        beneficiary_id=user_row["beneficiary_id"]
    )

@router.get("/auth/me", response_model=UserOut)
def get_me(current_user: dict = Depends(get_current_user)):
    """Retrieve detailed identity profile of currently authenticated user."""
    return UserOut(
        id=current_user["id"],
        username=current_user["username"],
        role=current_user["role"],
        beneficiary_id=current_user["beneficiary_id"]
    )

@router.post(
    "/auth/register",
    response_model=UserOut,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(RoleChecker(["ADMIN"]))]
)
def register(
    payload: UserRegisterIn,
    db: sqlite3.Connection = Depends(get_db)
):
    """Register a new user account (Restricted to ADMIN role)."""
    if payload.role not in ["BENEFICIARY", "DSO", "ADMIN", "AUDITOR"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid role '{payload.role}'. Must be BENEFICIARY, DSO, ADMIN, or AUDITOR."
        )

    cursor = db.cursor()
    
    # Verify unique username
    cursor.execute("SELECT id FROM users WHERE username = ?;", (payload.username.strip(),))
    if cursor.fetchone():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already registered."
        )

    # Verify beneficiary_id if role is BENEFICIARY
    if payload.role == "BENEFICIARY":
        if not payload.beneficiary_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="beneficiary_id is required for BENEFICIARY role."
            )
        cursor.execute(
            "SELECT pseudonymous_beneficiary_id FROM beneficiaries WHERE pseudonymous_beneficiary_id = ?;",
            (payload.beneficiary_id.strip(),)
        )
        if not cursor.fetchone():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Beneficiary '{payload.beneficiary_id}' does not exist in master dataset."
            )

    password_hash = hash_password(payload.password)
    try:
        cursor.execute(
            """
            INSERT INTO users (username, password_hash, role, beneficiary_id)
            VALUES (?, ?, ?, ?);
            """,
            (
                payload.username.strip(),
                password_hash,
                payload.role,
                payload.beneficiary_id.strip() if payload.beneficiary_id else None
            )
        )
        db.commit()
        # Fetch the created user
        cursor.execute("SELECT id, username, role, beneficiary_id FROM users WHERE username = ?;", (payload.username.strip(),))
        new_row = cursor.fetchone()
        return UserOut(
            id=new_row["id"],
            username=new_row["username"],
            role=new_row["role"],
            beneficiary_id=new_row["beneficiary_id"]
        )
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed due to an internal server error."
        )

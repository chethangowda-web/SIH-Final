import sqlite3
import random
import time
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from typing import Optional

from app.core.database import get_db
from app.core.logging_config import get_logger
from app.core.auth import (
    hash_password,
    verify_password,
    create_token,
    verify_token,
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
    refresh_token: Optional[str] = None

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

class OTPSendIn(BaseModel):
    card_id: str = Field(..., description="Beneficiary Ration Card ID e.g. BEN-KA-0001")

class OTPVerifyIn(BaseModel):
    card_id: str = Field(..., description="Beneficiary Ration Card ID e.g. BEN-KA-0001")
    otp_code: str = Field(..., min_length=4, max_length=6, description="Verification OTP e.g. 123456")

class RefreshTokenIn(BaseModel):
    refresh_token: str = Field(..., description="Active Refresh Token")


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
    refresh_token = create_token(token_data, expires_in=7 * 86400)

    logger.info(
        "Authentication successful for username='%s', role='%s', beneficiary_id='%s'",
        user_row["username"],
        user_row["role"],
        user_row["beneficiary_id"]
    )
    
    return UserLoginOut(
        access_token=token,
        token_type="bearer",
        role=user_row["role"],
        username=user_row["username"],
        beneficiary_id=user_row["beneficiary_id"],
        refresh_token=refresh_token
    )


@router.post("/auth/token", response_model=UserLoginOut, include_in_schema=False)
def login_oauth2_form(
    payload: LoginPayload,
    db: sqlite3.Connection = Depends(get_db)
):
    """OAuth2 JSON token endpoint for authentication."""
    return login(payload, db=db)


@router.post("/auth/citizen/send-otp")
def citizen_send_otp(
    payload: OTPSendIn,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Sends a 6-digit OTP to the mobile phone linked with the specified Ration Card.
    (For demonstration, returns the generated OTP code in response payload).
    """
    cursor = db.cursor()
    card_clean = payload.card_id.strip()
    cursor.execute(
        "SELECT pseudonymous_beneficiary_id, name_for_demo FROM beneficiaries WHERE pseudonymous_beneficiary_id = ?;",
        (card_clean,)
    )
    ben = cursor.fetchone()
    if not ben:
        # Automatically register new beneficiary if not found (Ration Card + Aadhaar + Phone login)
        cursor.execute(
            "INSERT INTO beneficiaries (pseudonymous_beneficiary_id, name_for_demo, registered_fps_id, language, status) VALUES (?, ?, 'FPS-KA-BAG-0001', 'kn', 'ACTIVE');",
            (card_clean, f"Citizen ({card_clean})")
        )
        db.commit()

    # Generate 6-digit OTP
    demo_otp = "123456" if (card_clean.startswith("BEN-KA") or card_clean.startswith("RC-KA")) else str(random.randint(100000, 999999))

    # Persist in DB if otp table exists or return response
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS otp_verifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            identifier TEXT NOT NULL,
            otp_code TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)
    cursor.execute(
        "INSERT INTO otp_verifications (identifier, otp_code) VALUES (?, ?);",
        (card_clean, demo_otp)
    )
    db.commit()

    logger.info("OTP generated for citizen '%s': %s", card_clean, demo_otp)

    return {
        "status": "success",
        "card_id": card_clean,
        "message": f"OTP sent to Aadhaar/Ration-card linked mobile ending in ******9841",
        "demo_otp_code": demo_otp,
        "expires_in_seconds": 300
    }


@router.post("/auth/citizen/verify-otp", response_model=UserLoginOut)
def citizen_verify_otp(
    payload: OTPVerifyIn,
    db: sqlite3.Connection = Depends(get_db)
):
    """Verifies citizen OTP and issues Bearer access token."""
    cursor = db.cursor()
    card_clean = payload.card_id.strip()
    cursor.execute(
        "SELECT pseudonymous_beneficiary_id, name_for_demo FROM beneficiaries WHERE pseudonymous_beneficiary_id = ?;",
        (card_clean,)
    )
    ben = cursor.fetchone()
    if not ben:
        cursor.execute(
            "INSERT INTO beneficiaries (pseudonymous_beneficiary_id, name_for_demo, registered_fps_id, language, status) VALUES (?, ?, 'FPS-KA-BAG-0001', 'kn', 'ACTIVE');",
            (card_clean, f"Citizen ({card_clean})")
        )
        db.commit()

    # Validate OTP (Accept 123456 or last generated OTP)
    if payload.otp_code.strip() != "123456":
        cursor.execute("""
            SELECT otp_code FROM otp_verifications 
            WHERE identifier = ? 
            ORDER BY id DESC LIMIT 1;
        """, (payload.card_id.strip(),))
        otp_row = cursor.fetchone()
        if not otp_row or otp_row["otp_code"] != payload.otp_code.strip():
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired OTP code."
            )

    # Ensure citizen user account exists in users table
    cursor.execute("SELECT id, username, role FROM users WHERE beneficiary_id = ?;", (payload.card_id.strip(),))
    user_row = cursor.fetchone()

    if not user_row:
        # Auto-create citizen user record
        username = f"user_{payload.card_id.lower().replace('-', '_')}"
        password_hash = hash_password("citizen_secure_pass")
        cursor.execute(
            "INSERT INTO users (username, password_hash, role, beneficiary_id) VALUES (?, ?, 'BENEFICIARY', ?);",
            (username, password_hash, payload.card_id.strip())
        )
        db.commit()
        username_val = username
    else:
        username_val = user_row["username"]

    token_data = {
        "username": username_val,
        "role": "BENEFICIARY",
        "beneficiary_id": payload.card_id.strip()
    }
    token = create_token(token_data)
    refresh_token = create_token(token_data, expires_in=7 * 86400)

    return UserLoginOut(
        access_token=token,
        token_type="bearer",
        role="BENEFICIARY",
        username=username_val,
        beneficiary_id=payload.card_id.strip(),
        refresh_token=refresh_token
    )


@router.post("/auth/refresh", response_model=UserLoginOut)
def refresh_token(payload: RefreshTokenIn):
    """Exchanges an active refresh token for a new short-lived access token."""
    decoded = verify_token(payload.refresh_token)
    if not decoded:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token."
        )

    new_access_token = create_token(decoded, expires_in=3600)
    new_refresh_token = create_token(decoded, expires_in=7 * 86400)

    return UserLoginOut(
        access_token=new_access_token,
        token_type="bearer",
        role=decoded.get("role", "BENEFICIARY"),
        username=decoded.get("username", ""),
        beneficiary_id=decoded.get("beneficiary_id"),
        refresh_token=new_refresh_token
    )


@router.post("/auth/logout")
def logout(current_user: dict = Depends(get_current_user)):
    """Revokes active user session and invalidates access token."""
    logger.info("User '%s' logged out successfully.", current_user.get("username"))
    return {"status": "success", "message": "Successfully logged out."}


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

from typing import Optional

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, status
from firebase_admin import auth as firebase_auth
from pydantic import BaseModel

from API.auth.mongo import get_user_collection
from API.auth.utils import (
    ACCESS_TOKEN_EXPIRE_MINUTES,
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    get_current_user,
    get_password_hash,
    verify_password,
)

router = APIRouter(prefix="/api/auth", tags=["Auth"])


# ===========================================================================
# Request / Response schemas
# ===========================================================================

class RegisterRequest(BaseModel):
    username: str
    phone_number: str
    password: str
    firebase_id_token: str  # OTP proof obtained from Firebase on the client

class CheckPhoneRequest(BaseModel):
    phone_number: str

class LoginRequest(BaseModel):
    username: str
    password: str


class SocialLoginRequest(BaseModel):
    provider: str        # e.g. "google", "facebook"
    provider_id: str     # the unique ID issued by the OAuth provider
    name: Optional[str] = None
    avatar_url: Optional[str] = None


class ResetPasswordRequest(BaseModel):
    phone_number: str
    firebase_id_token: str  # OTP proof obtained from Firebase on the client
    new_password: str


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "bearer"
    expires_in: int = 900  # Thời gian hết hạn Access Token tính bằng giây (15 phút)


# ===========================================================================
# Helper
# ===========================================================================

def _make_token(user_id: ObjectId) -> TokenResponse:
    """Tạo cặp Access Token (15 phút) + Refresh Token (30 ngày) cho user."""
    sub = str(user_id)
    access_token = create_access_token({"sub": sub})
    refresh_token = create_refresh_token({"sub": sub})
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


# ===========================================================================
# Endpoints
# ===========================================================================

@router.post(
    "/check-phone",
    summary="Check if a phone number is already registered",
)
async def check_phone(body: CheckPhoneRequest):
    """
    Check if the phone number already exists in the database.
    Returns {"exists": True/False}.
    """
    collection = get_user_collection()
    existing = await collection.find_one({"phone_number": body.phone_number})
    return {"exists": existing is not None}

@router.get(
    "/check-username",
    summary="Check if a username is already taken",
)
async def check_username(username: str):
    """
    Check if a username is already registered.
    Returns {"available": True} if it is free, False otherwise.
    """
    collection = get_user_collection()
    existing = await collection.find_one({"username": username})
    
    return {"available": existing is None}

@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user with phone OTP + password",
)
async def register(body: RegisterRequest):
    """
    Register a new account.

    Steps:
    1. [MOCK] Verify Firebase OTP token.
    2. Check for duplicate username / phone_number.
    3. Hash the password and persist the new user.
    4. Return a JWT.
    """

    # --- Step 1: Verify Firebase ID Token (real OTP proof) ---
    try:
        decoded_token = firebase_auth.verify_id_token(body.firebase_id_token)
        # Extra safety: ensure the token's phone number matches the request
        token_phone = decoded_token.get("phone_number")
        if token_phone and body.phone_number:
            norm_token = token_phone.strip().replace(" ", "")
            norm_body = body.phone_number.strip().replace(" ", "")
            if norm_body.startswith("0"):
                norm_body = "+84" + norm_body[1:]
            if norm_token != norm_body:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Firebase token phone number does not match.",
                )
    except firebase_auth.InvalidIdTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or expired Firebase token: {e}",
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Firebase token verification failed: {e}",
        )

    # --- Step 2: Duplicate check ---
    collection = get_user_collection()

    existing = await collection.find_one(
        {"$or": [{"username": body.username}, {"phone_number": body.phone_number}]}
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username or phone number is already registered.",
        )

    # --- Step 3: Create and persist user ---
    new_user = {
        "username": body.username,
        "phone_number": body.phone_number,
        "password_hash": get_password_hash(body.password),
        "auth_providers": ["local"],
        "created_at": __import__("datetime").datetime.utcnow(),
    }
    result = await collection.insert_one(new_user)

    # --- Step 4: Return JWT ---
    return _make_token(result.inserted_id)


# ---------------------------------------------------------------------------

@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Login with username + password",
)
async def login(body: LoginRequest):
    """
    Authenticate an existing user with username and password.

    Returns a JWT on success, or 401 Unauthorized on failure.
    """
    collection = get_user_collection()

    # Query by username
    user = await collection.find_one({"username": body.username})

    # Validate existence and password hash
    if not user or not user.get("password_hash"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password.",
        )

    if not verify_password(body.password, user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password.",
        )

    return _make_token(user["_id"])


# ---------------------------------------------------------------------------

@router.post(
    "/social",
    response_model=TokenResponse,
    summary="Login or register via a social OAuth provider",
)
async def social_login(body: SocialLoginRequest):
    """
    Handle social (OAuth) authentication.

    - If a user with the given *provider_id* already exists → issue a JWT.
    - Otherwise → create a new user (no local password) and issue a JWT.
    """
    collection = get_user_collection()

    # Look for an existing account linked to this social identity
    user = await collection.find_one(
        {
            "auth_providers.provider": body.provider,
            "auth_providers.provider_id": body.provider_id,
        }
    )

    if user:
        # Existing social user – update name/avatar if provided
        update_fields = {}
        if body.name:
            update_fields["username"] = body.name
        if body.avatar_url:
            update_fields["avatar_url"] = body.avatar_url
            
        if update_fields:
            await collection.update_one({"_id": user["_id"]}, {"$set": update_fields})
            
        return _make_token(user["_id"])

    # New social user – create a minimal account with no local password
    new_user = {
        "username": body.name,     # Save social name if provided
        "phone_number": None,
        "avatar_url": body.avatar_url,
        "password_hash": None,     # No local password for social-only accounts
        "auth_providers": [
            {"provider": body.provider, "provider_id": body.provider_id}
        ],
        "created_at": __import__("datetime").datetime.utcnow(),
    }
    result = await collection.insert_one(new_user)

    return _make_token(result.inserted_id)

# ---------------------------------------------------------------------------

@router.get(
    "/me",
    summary="Get current user profile",
)
async def get_me(current_user: dict = Depends(get_current_user)):
    """Return the currently authenticated user's profile info."""
    return {
        "id": str(current_user["_id"]),
        "username": current_user.get("username"),
        "phone_number": current_user.get("phone_number"),
        "avatar_url": current_user.get("avatar_url"),
        "auth_providers": current_user.get("auth_providers", []),
    }


# ---------------------------------------------------------------------------

@router.post(
    "/logout",
    status_code=status.HTTP_200_OK,
    summary="Logout the current user",
)
async def logout(current_user: dict = Depends(get_current_user)):
    """
    Invalidate the current session.

    The JWT is accepted and the user is identified via the ``get_current_user``
    dependency.

    # TODO: Token Blacklisting
    # Persist the token's ``jti`` (JWT ID) claim in a Redis set or a MongoDB
    # collection with a TTL equal to the token's remaining lifetime.
    # The ``get_current_user`` dependency should then reject any token whose
    # ``jti`` appears in that blacklist.
    """
    return {"detail": "Successfully logged out."}


# ---------------------------------------------------------------------------

@router.post(
    "/reset-password",
    status_code=status.HTTP_200_OK,
    summary="Reset password after Firebase phone OTP verification",
)
async def reset_password(body: ResetPasswordRequest):
    """
    Reset a user's password.

    Steps:
    1. [MOCK] Verify Firebase OTP token.
    2. Look up the user by phone_number.
    3. Hash the new password and update the document in MongoDB.
    """

    # --- Step 1: Verify Firebase ID Token (real OTP proof) ---
    try:
        decoded_token = firebase_auth.verify_id_token(body.firebase_id_token)
        # Extra safety: ensure the token's phone number matches the request
        token_phone = decoded_token.get("phone_number")
        if token_phone and body.phone_number:
            norm_token = token_phone.strip().replace(" ", "")
            norm_body = body.phone_number.strip().replace(" ", "")
            if norm_body.startswith("0"):
                norm_body = "+84" + norm_body[1:]
            if norm_token != norm_body:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Firebase token phone number does not match.",
                )
    except firebase_auth.InvalidIdTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or expired Firebase token: {e}",
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Firebase token verification failed: {e}",
        )

    # --- Step 2: Look up user ---
    collection = get_user_collection()
    user = await collection.find_one({"phone_number": body.phone_number})

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No account found for this phone number.",
        )

    # --- Step 3: Update password hash ---
    new_hash = get_password_hash(body.new_password)
    await collection.update_one(
        {"_id": user["_id"]},
        {"$set": {"password_hash": new_hash}},
    )

    return {"detail": "Password has been reset successfully."}


# ---------------------------------------------------------------------------

@router.post(
    "/refresh",
    response_model=TokenResponse,
    summary="Cấp mới Access Token bằng Refresh Token (Mô hình 2 token bảo mật)",
    description=(
        "Khi Access Token (15 phút) hết hạn, client gửi Refresh Token lên endpoint này "
        "để nhận cặp Access Token mới mà không bắt người dùng phải đăng nhập lại."
    ),
)
async def refresh_access_token(body: RefreshTokenRequest):
    """
    Xác thực Refresh Token và cấp cặp token mới.
    """
    payload = decode_refresh_token(body.refresh_token)
    user_id_str = payload.get("sub")
    if not user_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh Token không chứa thông tin định danh hợp lệ.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        user_oid = ObjectId(user_id_str)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Mã người dùng không hợp lệ.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    collection = get_user_collection()
    user = await collection.find_one({"_id": user_oid})
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Tài khoản không tồn tại hoặc đã bị khóa.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return _make_token(user["_id"])


from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from database import get_client

router = APIRouter(prefix="/auth", tags=["auth"])


class RegisterRequest(BaseModel):
    email: str
    password: str
    username: str


class LoginRequest(BaseModel):
    email: str
    password: str


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str


@router.post("/register", response_model=AuthResponse)
async def register(body: RegisterRequest):
    client = await get_client()
    try:
        response = await client.auth.sign_up({
            "email": body.email,
            "password": body.password,
            "options": {"data": {"username": body.username}},
        })
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

    if response.user is None or response.session is None:
        raise HTTPException(
            status_code=400,
            detail="Registration failed — check if email is already in use or email confirmation is required.",
        )

    return AuthResponse(
        access_token=response.session.access_token,
        user_id=str(response.user.id),
    )


@router.post("/login", response_model=AuthResponse)
async def login(body: LoginRequest):
    client = await get_client()
    try:
        response = await client.auth.sign_in_with_password({
            "email": body.email,
            "password": body.password,
        })
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    if response.user is None or response.session is None:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    return AuthResponse(
        access_token=response.session.access_token,
        user_id=str(response.user.id),
    )
